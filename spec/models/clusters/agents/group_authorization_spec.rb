# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::GroupAuthorization do
  it { is_expected.to belong_to(:agent).class_name('Clusters::Agent').required }
  it { is_expected.to belong_to(:group).class_name('::Group').required }

  it { expect(described_class).to validate_jsonb_schema(['config']) }
end
