# frozen_string_literal: true

module QA
  context 'Plan' do
    describe 'mention' do
      it 'user mentions another user in an issue' do
        QA::Runtime::Env.personal_access_token = QA::Runtime::Env.admin_personal_access_token

        unless QA::Runtime::Env.personal_access_token
          Runtime::Browser.visit(:gitlab, Page::Main::Login)
          Page::Main::Login.perform(&:sign_in_using_admin_credentials)
        end

        user = Resource::User.fabricate_via_api! do |user|
          user.name = "bob"
          user.password = "1234test"
        end

        QA::Runtime::Env.personal_access_token = nil

        Page::Main::Menu.perform(&:sign_out) if Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }

        Runtime::Browser.visit(:gitlab, Page::Main::Login)

        Page::Main::Login.perform(&:sign_in_using_credentials)

        project = Resource::Project.fabricate_via_api! do |resource|
          resource.name = 'project-to-test-mention'
        end
        project.visit!

        Page::Project::Show.perform(&:go_to_members_settings)
        Page::Project::Settings::Members.perform do |page|
          page.add_member(user.username)
        end

        issue = Resource::Issue.fabricate_via_api! do |issue|
          issue.title = 'issue to test mention'
          issue.project = project
        end
        issue.visit!

        Page::Project::Issue::Show.perform do |show|
          at_username = "@#{user.username}"

          show.select_all_activities_filter
          show.comment(at_username)

          expect(show).to have_content(at_username)
        end
      end
    end
  end
end
