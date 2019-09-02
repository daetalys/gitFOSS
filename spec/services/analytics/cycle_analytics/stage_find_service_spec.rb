# frozen_string_literal: true

require 'spec_helper'

describe Analytics::CycleAnalytics::StageFindService do
  it 'finds in-memory default stage' do
    found_stage = described_class.new(parent: build(:project), id: 'code').execute # code (default) stage name

    code_stage_params = Gitlab::Analytics::CycleAnalytics::DefaultStages.params_for_code_stage
    expect(found_stage.name).to eq(code_stage_params[:name])
    expect(found_stage.start_event_identifier.to_sym).to eq(code_stage_params[:start_event_identifier])
    expect(found_stage.end_event_identifier.to_sym).to eq(code_stage_params[:end_event_identifier])
  end

  it 'raises ActiveRecord::RecordNotFound when in-memory default stage cannot be found' do
    expect do
      described_class.new(parent: build(:project), id: 'UnknownDefaultStage').execute
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
