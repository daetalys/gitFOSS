# frozen_string_literal: true

require 'spec_helper'

describe ErrorTracking::ListProjectsService do
  include ReactiveCachingHelpers

  set(:user) { create(:user) }
  set(:project) { create(:project) }

  let(:sentry_url) { 'https://sentrytest.gitlab.com/api/0/projects/sentry-org/sentry-project' }
  let(:token) { 'test-token' }
  let(:new_api_host) { 'https://gitlab.com/' }
  let(:new_token) { 'new-token' }
  let(:params) { ActionController::Parameters.new(api_host: new_api_host, token: new_token) }

  let(:error_tracking_setting) do
    create(:project_error_tracking_setting, api_url: sentry_url, token: token, project: project)
  end

  subject { described_class.new(project, user, params) }

  before do
    project.add_reporter(user)
  end

  describe '#execute' do
    let(:result) { subject.execute }

    context 'with authorized user' do
      let(:sentry_client) { spy(:sentry_client) }

      before do
        expect(project).to receive(:error_tracking_setting).at_least(:once)
          .and_return(error_tracking_setting)
      end

      context 'call sentry client' do
        before do
          synchronous_reactive_cache(error_tracking_setting)
        end

        it 'uses new api_url and token' do
          expect(Sentry::Client).to receive(:new)
            .with(new_api_host + 'api/0/projects/', new_token)
            .and_return(sentry_client)
          expect(sentry_client).to receive(:list_projects).and_return([])

          subject.execute

          error_tracking_setting.reload
          expect(error_tracking_setting.api_url).to eq(sentry_url)
          expect(error_tracking_setting.token).to eq(token)
        end
      end

      context 'with invalid url' do
        let(:params) do
          ActionController::Parameters.new(
            api_host: 'https://localhost',
            token: new_token
          )
        end

        before do
          error_tracking_setting.enabled = false
        end

        it 'returns error' do
          expect(result[:message]).to start_with('Api url is blocked')
          expect(error_tracking_setting).not_to be_valid
        end
      end

      context 'when list_sentry_projects returns projects' do
        let(:projects) { [:list, :of, :projects] }

        before do
          expect(error_tracking_setting)
            .to receive(:list_sentry_projects).and_return(projects: projects)
        end

        it 'returns the projects' do
          expect(result).to eq(status: :success, projects: projects)
        end
      end

      context 'when list_sentry_projects returns nil' do
        before do
          expect(error_tracking_setting)
            .to receive(:list_sentry_projects).and_return(nil)
        end

        it 'result is not ready' do
          result = subject.execute

          expect(result).to eq(
            status: :error,
            http_status: :no_content,
            message: 'not ready'
          )
        end
      end

      context 'when list_sentry_projects returns empty array' do
        before do
          expect(error_tracking_setting)
            .to receive(:list_sentry_projects).and_return({ projects: [] })
        end

        it 'returns the empty array' do
          result = subject.execute

          expect(result).to eq(
            status: :success,
            projects: []
          )
        end
      end
    end

    context 'with unauthorized user' do
      before do
        project.add_guest(user)
      end

      it 'returns error' do
        expect(result).to include(status: :error, message: 'access denied')
      end
    end

    context 'with error tracking disabled' do
      before do
        expect(project).to receive(:error_tracking_setting).at_least(:once)
          .and_return(error_tracking_setting)
        expect(error_tracking_setting)
          .to receive(:list_sentry_projects).and_return(projects: [])

        error_tracking_setting.enabled = false
        error_tracking_setting.save!
      end

      it 'ignores enabled flag' do
        expect(result).to include(status: :success, projects: [])

        error_tracking_setting.reload
        expect(error_tracking_setting.enabled).to be false
      end
    end

    context 'error_tracking_setting is nil' do
      let(:error_tracking_setting) { build(:project_error_tracking_setting) }

      before do
        expect(project).to receive(:error_tracking_setting).at_least(:once)
          .and_return(nil)

        expect(project).to receive(:build_error_tracking_setting).once
          .and_return(error_tracking_setting)

        expect(error_tracking_setting).to receive(:list_sentry_projects)
          .and_return(projects: [:project1, :project2])
      end

      it 'builds a new error_tracking_setting' do
        expect(result[:projects]).to eq([:project1, :project2])
        expect(project.error_tracking_setting).to be_nil
      end
    end
  end
end
