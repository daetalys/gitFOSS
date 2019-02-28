# frozen_string_literal: true
#
# 1. Give the merge request IID to the params
# 2. Give the file path (the preview is scoped by file)

module PreviewMarkdown
  extend ActiveSupport::Concern

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def preview_markdown
    result = PreviewMarkdownService.new(@project, current_user, params).execute

    markdown_params =
      case controller_name
      when 'wikis'    then { pipeline: :wiki, project_wiki: @project_wiki, page_slug: params[:id] }
      when 'snippets' then { skip_project_check: true }
      when 'groups'   then { group: group }
      when 'projects' then projects_filter_params
      else {}
      end

    render json: {
      body: view_context.markdown(result[:text], markdown_params),
      references: {
        users: result[:users],
        suggestions: result[:suggestions],
        commands: view_context.markdown(result[:commands])
      }
    }
  end

  def projects_filter_params
    {
      issuable_state_filter_enabled: true,
      suggestions_filter_enabled: params[:preview_suggestions].present?
    }
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end
