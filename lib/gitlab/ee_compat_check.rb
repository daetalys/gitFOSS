# frozen_string_literal: true

# rubocop: disable Rails/Output
module Gitlab
  # Checks if a set of migrations requires downtime or not.
  class EeCompatCheck
    CANONICAL_CE_PROJECT_URL = 'https://gitlab.com/gitlab-org/gitlab-ce'.freeze
    CANONICAL_EE_REPO_URL = 'https://gitlab.com/gitlab-org/gitlab-ee.git'.freeze
    CHECK_DIR = Rails.root.join('ee_compat_check')
    DEFAULT_TARGET = 'master'.freeze
    IGNORED_FILES_REGEX = /VERSION|CHANGELOG\.md/i.freeze
    PLEASE_READ_THIS_BANNER = %Q{
      ============================================================
      ===================== PLEASE READ THIS =====================
      ============================================================
    }.freeze
    STAY_STRONG_LINK_TO_DOCS = %Q{
      Stay 💪! For more information, see
      https://docs.gitlab.com/ce/development/automatic_ce_ee_merge.html
    }.freeze
    THANKS_FOR_READING_BANNER = %Q{
      ============================================================
      ==================== THANKS FOR READING ====================
      ============================================================\n
    }.freeze

    attr_reader :ee_repo_dir, :patches_dir
    attr_reader :ce_project_url, :ee_repo_url
    attr_reader :ce_branch, :ee_remote_with_branch, :ee_branch_found
    attr_reader :failed_files
    attr_reader :ce_target_branch, :ee_target_branch

    def initialize(branch:, ce_project_url: CANONICAL_CE_PROJECT_URL)
      @ee_repo_dir = CHECK_DIR.join('ee-repo')
      @patches_dir = CHECK_DIR.join('patches')
      @ce_branch = branch
      @ce_project_url = ce_project_url
      @ee_repo_url = ce_public_repo_url.sub(/gitlab(-ce|hq)/, 'gitlab-ee')

      @ce_target_branch = ENV.fetch('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', DEFAULT_TARGET)
      @ee_target_branch = @ce_target_branch.dup.tap do |target|
        target << '-ee' unless target == DEFAULT_TARGET
      end
    end

    def check
      ensure_patches_dir
      # We're generating the patch against the canonical-ce remote since forks'
      # master branch are not necessarily up-to-date.
      add_remote('canonical-ce', "#{CANONICAL_CE_PROJECT_URL}.git")
      generate_patch(ce_patch_full_path, source: "origin/#{ce_branch}", target: "canonical-ce/#{ce_target_branch}")

      ensure_ee_repo
      Dir.chdir(ee_repo_dir) do
        step("In the #{ee_repo_dir} directory")

        ee_remotes.each do |key, url|
          add_remote(key, url)
        end
        fetch("canonical-ee/#{ee_target_branch}", depth: 20)

        status = catch(:halt_check) do
          ce_branch_compat_check!
          delete_ee_branches_locally!
          ee_branch_presence_check!

          source = "#{ee_remote_with_branch}/#{ee_branch_found}"

          step("Checking out #{source}", %W[git checkout -b #{ee_branch_found} #{source}])
          generate_patch(ee_patch_full_path, source: source, target: "canonical-ee/#{ee_target_branch}")
          ee_branch_compat_check!
        end

        delete_ee_branches_locally!

        status.nil?
      end
    end

    private

    def fork?
      ce_project_url != CANONICAL_CE_PROJECT_URL
    end

    def ee_remotes
      return @ee_remotes if defined?(@ee_remotes)

      remotes =
        {
          'ee' => ee_repo_url,
          'canonical-ee' => CANONICAL_EE_REPO_URL
        }
      remotes.delete('ee') unless fork?

      @ee_remotes = remotes
    end

    def add_remote(name, url)
      step(
        "Adding the #{name} remote (#{url})",
        %W[git remote add #{name} #{url}]
      )
    end

    def ensure_ee_repo
      unless clone_ee_repo(ee_repo_url, ee_repo_dir)
        # Fallback to using the canonical EE if there is no forked EE
        clone_ee_repo(CANONICAL_EE_REPO_URL, ee_repo_dir)
      end
    end

    def clone_ee_repo(url, dir)
      _, status = step(
        "Cloning #{url} into #{dir}",
        %W[git clone --branch #{ee_target_branch} --single-branch --depth=200 #{url} #{dir}]
      )
      status.zero?
    end

    def ensure_patches_dir
      FileUtils.mkdir_p(patches_dir)
    end

    def generate_patch(patch_path, source:, target:)
      FileUtils.rm(patch_path, force: true)

      find_merge_base_with_master(source: source, target: target)

      step(
        "Generating the patch against #{target} in #{patch_path}",
        %W[git diff --binary #{target}...#{source}]
      ) do |output, status|
        throw(:halt_check, :ko) unless status.zero?

        File.write(patch_path, output)

        throw(:halt_check, :ko) unless File.exist?(patch_path)
      end
    end

    def ce_branch_compat_check!
      if check_patch(ce_patch_full_path).zero?
        puts applies_cleanly_msg(ce_branch)
        throw(:halt_check)
      end
    end

    def ee_branch_presence_check!
      ee_remotes.keys.each do |remote|
        output, _ = step(
          "Searching #{remote}",
          %W[git ls-remote #{remote} *#{minimal_ee_branch_name}*])

        branches =
          output.scan(%r{(?<=refs/heads/|refs/tags/).+}).sort_by(&:size)

        next if branches.empty?

        branch = branches.first

        step("Fetching #{remote}/#{branch}", %W[git fetch #{remote} #{branch}])

        @ee_remote_with_branch = remote
        @ee_branch_found = branch

        return true
      end

      puts
      puts ce_branch_doesnt_apply_cleanly_and_no_ee_branch_msg

      throw(:halt_check, :ko)
    end

    def ee_branch_compat_check!
      unless check_patch(ee_patch_full_path).zero?
        puts
        puts ee_branch_doesnt_apply_cleanly_msg

        throw(:halt_check, :ko)
      end

      puts
      puts applies_cleanly_msg(ee_branch_found)
    end

    def check_patch(patch_path)
      step("Checking out #{ee_target_branch}", %W[git checkout #{ee_target_branch}])
      step("Resetting to latest #{ee_target_branch}", %W[git reset --hard canonical-ee/#{ee_target_branch}])
      step(
        "Checking if #{patch_path} applies cleanly to EE/#{ee_target_branch}",
        # Don't use --check here because it can result in a 0-exit status even
        # though the patch doesn't apply cleanly, e.g.:
        #   > git apply --check --3way foo.patch
        #   error: patch failed: lib/gitlab/ee_compat_check.rb:74
        #   Falling back to three-way merge...
        #   Applied patch to 'lib/gitlab/ee_compat_check.rb' with conflicts.
        #   > echo $?
        #   0
        %W[git apply --3way #{patch_path}]
      ) do |output, status|
        puts output

        unless status.zero?
          @failed_files = output.lines.reduce([]) do |memo, line|
            if line.start_with?('error: patch failed:')
              file = line.sub(/\Aerror: patch failed: /, '')
              memo << file unless file =~ IGNORED_FILES_REGEX
            end

            memo
          end

          status = 0 if failed_files.empty?
        end

        command(%w[git reset --hard])
        status
      end
    end

    def delete_ee_branches_locally!
      command(%W[git checkout #{ee_target_branch}])
      command(%W[git branch --delete --force #{ee_branch_prefix}])
      command(%W[git branch --delete --force #{ee_branch_suffix}])
    end

    def merge_base_found?(source:, target:)
      step(
        "Finding merge base with #{target}",
        %W[git merge-base #{target} #{source}]
      ) do |output, status|
        if status.zero?
          puts "Merge base was found: #{output}"
          true
        end
      end
    end

    # TODO (rspeicher): Not always master
    def find_merge_base_with_master(source:, target:)
      # Start with (Math.exp(3).to_i = 20) until (Math.exp(6).to_i = 403)
      # In total we go (20 + 54 + 148 + 403 = 625) commits deeper
      depth = 20
      success =
        (3..6).any? do |factor|
          depth += Math.exp(factor).to_i
          # Repository is initially cloned with a depth of 20 so we need to fetch
          # deeper in the case the branch has more than 20 commits on top of master
          fetch(source, depth: depth)
          fetch(target, depth: depth)

          merge_base_found?(source: source, target: target)
        end

      raise "\n#{source} is too far behind #{target}, please rebase it!\n" unless success
    end

    def fetch(source, depth:)
      remote, branch = source.split('/', 2)

      step(
        "Fetching deeper...",
        %W[git fetch --depth=#{depth} --prune #{remote} +refs/heads/#{branch}:refs/remotes/#{remote}/#{branch}]
      ) do |output, status|
        raise "Fetch failed: #{output}" unless status.zero?
      end
    end

    def ce_patch_name
      @ce_patch_name ||= patch_name_from_branch(ce_branch)
    end

    def ce_patch_full_path
      @ce_patch_full_path ||= patches_dir.join(ce_patch_name)
    end

    def ee_branch_suffix
      @ee_branch_suffix ||= "#{ce_branch}-ee"
    end

    def ee_branch_prefix
      @ee_branch_prefix ||= "ee-#{ce_branch}"
    end

    def ee_patch_name
      @ee_patch_name ||= patch_name_from_branch(ee_branch_found)
    end

    def ee_patch_full_path
      @ee_patch_full_path ||= patches_dir.join(ee_patch_name)
    end

    def minimal_ee_branch_name
      @minimal_ee_branch_name ||= ce_branch.sub(/(\Ace\-|\-ce\z)/, '')
    end

    def patch_name_from_branch(branch_name)
      "#{branch_name.parameterize}.patch"
    end

    def patch_url
      "#{ENV['CI_JOB_URL']}/artifacts/raw/ee_compat_check/patches/#{ce_patch_name}"
    end

    def step(desc, cmd = nil)
      puts "\n=> #{desc}\n"

      if cmd
        start = Time.now
        puts "\n$ #{cmd.join(' ')}"

        output, status = command(cmd)
        puts "\n==> Finished in #{Time.now - start} seconds"

        if block_given?
          yield(output, status)
        else
          [output, status]
        end
      end
    end

    def command(cmd)
      Gitlab::Popen.popen(cmd)
    end

    # We're "re-creating" the repo URL because ENV['CI_REPOSITORY_URL'] contains
    # redacted credentials (e.g. "***:****") which are useless in instructions
    # the job gives.
    def ce_public_repo_url
      "#{ce_project_url}.git"
    end

    def applies_cleanly_msg(branch)
      %Q{
        #{PLEASE_READ_THIS_BANNER}
        🎉 Congratulations!! 🎉

        The `#{branch}` branch applies cleanly to EE/#{ee_target_branch}!

        Much ❤️! For more information, see
        https://docs.gitlab.com/ce/development/automatic_ce_ee_merge.html
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def ce_branch_doesnt_apply_cleanly_and_no_ee_branch_msg
      ee_repos = ee_remotes.values.uniq

      %Q{
        #{PLEASE_READ_THIS_BANNER}
        💥 Oh no! 💥

        The `#{ce_branch}` branch does not apply cleanly to the current
        EE/#{ee_target_branch}, and no `#{ee_branch_prefix}` or `#{ee_branch_suffix}` branch
        was found in #{ee_repos.join(' nor in ')}.

        If you're a community contributor, don't worry, someone from
        GitLab Inc. will take care of this, and you don't have to do anything.
        If you're willing to help, and are ok to contribute to EE as well,
        you're welcome to help. You could follow the instructions below.

        #{conflicting_files_msg}

        We advise you to create a `#{ee_branch_prefix}` or `#{ee_branch_suffix}`
        branch that includes changes from `#{ce_branch}` but also specific changes
        than can be applied cleanly to EE/#{ee_target_branch}. In some cases, the conflicts
        are trivial and you can ignore the warning from this job. As always,
        use your best judgement!

        There are different ways to create such branch:

        1. Create a new branch from #{ee_target_branch} and cherry-pick your CE commits

          # In the EE repo
          $ git fetch #{CANONICAL_EE_REPO_URL} #{ee_target_branch}
          $ git checkout -b #{ee_branch_prefix} FETCH_HEAD
          $ git fetch #{ce_public_repo_url} #{ce_branch}
          $ git cherry-pick SHA # Repeat for all the commits you want to pick

          Note: You can squash the `#{ce_branch}` commits into a single "Port of #{ce_branch} to EE" commit.

        2. Apply your branch's patch to EE

          # In the EE repo
          $ git fetch #{CANONICAL_EE_REPO_URL} #{ee_target_branch}
          $ git checkout -b #{ee_branch_prefix} FETCH_HEAD
          $ wget #{patch_url} && git apply --3way #{ce_patch_name}

          At this point you might have conflicts such as:

            error: patch failed: lib/gitlab/ee_compat_check.rb:5
            Falling back to three-way merge...
            Applied patch to 'lib/gitlab/ee_compat_check.rb' with conflicts.
            U lib/gitlab/ee_compat_check.rb

          Resolve them, stage the changes and commit them.

          If the patch couldn't be applied cleanly, use the following command:

          # In the EE repo
          $ git apply --reject #{ce_patch_name}

          This option makes git apply the parts of the patch that are applicable,
          and leave the rejected hunks in corresponding `.rej` files.
          You can then resolve the conflicts highlighted in `.rej` by
          manually applying the correct diff from the `.rej` file to the file with conflicts.
          When finished, you can delete the `.rej` files and commit your changes.

        ⚠️ Don't forget to push your branch to gitlab-ee:

          # In the EE repo
          $ git push origin #{ee_branch_prefix}

        ⚠️ Also, don't forget to create a new merge request on gitlab-ee and
        cross-link it with the CE merge request.

        Once this is done, you can retry this failed job, and it should pass.

        #{STAY_STRONG_LINK_TO_DOCS}
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def ee_branch_doesnt_apply_cleanly_msg
      %Q{
        #{PLEASE_READ_THIS_BANNER}
        💥 Oh no! 💥

        The `#{ce_branch}` does not apply cleanly to the current EE/#{ee_target_branch}, and
        even though a `#{ee_branch_found}` branch
        exists in #{ee_repo_url}, it does not apply cleanly either to
        EE/#{ee_target_branch}!

        #{conflicting_files_msg}

        Please update the `#{ee_branch_found}`, push it again to gitlab-ee, and
        retry this job.

        #{STAY_STRONG_LINK_TO_DOCS}
        #{THANKS_FOR_READING_BANNER}
      }
    end

    def conflicting_files_msg
      header = "The conflicts detected were as follows:\n"
      separator = "\n        - "
      failed_items = failed_files.join(separator)

      "#{header}#{separator}#{failed_items}"
    end
  end
end
