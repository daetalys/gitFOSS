# frozen_string_literal: true

require 'spec_helper'

describe Banzai::SuggestionsParser do
  describe '.parse' do
    let(:merge_request) { create(:merge_request) }
    let(:project) { merge_request.project }
    let(:position) do
      Gitlab::Diff::Position.new(old_path: "files/ruby/popen.rb",
                                 new_path: "files/ruby/popen.rb",
                                 old_line: nil,
                                 new_line: 9,
                                 diff_refs: merge_request.diff_refs)
    end

    let(:diff_file) do
      position.diff_file(project.repository)
    end

    let(:markdown) do
      <<-MARKDOWN.strip_heredoc
        ```suggestion
          foo
          bar
        ```

        ```
          nothing
        ```

        ```suggestion:-2+3
          xpto
          baz
        ```

        ```thing
          this is not a suggestion, it's a thing
        ```
      MARKDOWN
    end

    subject do
      described_class.parse(markdown, project: merge_request.project,
                                      position: position)
    end

    def blob_lines_data(from_line, to_line)
      diff_file.new_blob_lines_between(from_line, to_line).join
    end

    it 'returns a list of Gitlab::Diff::Suggestion' do
      expect(subject).to all(be_a(Gitlab::Diff::Suggestion))
      expect(subject.size).to eq(2)
    end

    it 'parsed single-line suggestion has correct data' do
      from_line, to_line = position.new_line, position.new_line

      expect(subject.first.to_hash).to eq(from_content: blob_lines_data(from_line, to_line),
                                          to_content: "  foo\n  bar\n")
    end

    it 'parsed multi-line suggestion has correct data' do
      from_line = position.new_line - 2
      to_line = position.new_line + 3

      expect(subject.second.to_hash).to eq(from_content: blob_lines_data(from_line, to_line),
                                           to_content: "  xpto\n  baz\n")
    end
  end
end
