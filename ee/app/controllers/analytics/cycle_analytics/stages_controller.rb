# frozen_string_literal: true

module Analytics
  module CycleAnalytics
    class StagesController < Analytics::ApplicationController
      check_feature_flag Gitlab::Analytics::CYCLE_ANALYTICS_FEATURE_FLAG

      before_action :load_group

      def index
        return render_403 unless can?(current_user, :read_group_cycle_analytics, @group)

        result = list_service.execute

        if result.success?
          render json: cycle_analytics_configuration(result.payload[:stages])
        else
          render json: { message: result.message }, status: result.http_status
        end
      end

      def create
        return render_403 unless can?(current_user, :create_group_stage, @group)

        render_stage_service_result(create_service.execute)
      end

      def update
        return render_403 unless can?(current_user, :update_group_stage, @group)

        render_stage_service_result(update_service.execute)
      end

      def destroy
        return render_403 unless can?(current_user, :delete_group_stage, @group)

        render_stage_service_result(delete_service.execute)
      end

      private

      def cycle_analytics_configuration(stages)
        stage_presenters = stages.map { |s| StagePresenter.new(s) }

        Analytics::CycleAnalytics::ConfigurationEntity.new(stages: stage_presenters)
      end

      def list_service
        Stages::ListService.new(parent: @group, current_user: current_user)
      end

      def create_service
        Stages::CreateService.new(parent: @group, current_user: current_user, params: params.permit(:name, :start_event_identifier, :end_event_identifier))
      end

      def update_service
        Stages::UpdateService.new(parent: @group, current_user: current_user, params: params.permit(:name, :start_event_identifier, :end_event_identifier, :id))
      end

      def delete_service
        Stages::DeleteService.new(parent: @group, current_user: current_user, params: params.permit(:id))
      end

      def render_stage_service_result(result)
        if result.success?
          stage = StagePresenter.new(result.payload[:stage])
          render json: Analytics::CycleAnalytics::StageEntity.new(stage), status: result.http_status
        else
          render json: { message: result.message, errors: result.payload[:errors] }, status: result.http_status
        end
      end
    end
  end
end
