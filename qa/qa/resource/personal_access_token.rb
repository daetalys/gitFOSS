# frozen_string_literal: true

module QA
  module Resource
    ##
    # Create a personal access token that can be used by the api
    #
    class PersonalAccessToken < Base
      attr_accessor :name

      attribute :access_token do
        Page::Profile::PersonalAccessTokens.perform(&:created_access_token)
      end

      def fabricate!
        Page::Main::Menu.perform(&:go_to_profile_settings)
        Page::Profile::Menu.perform(&:click_access_tokens)

        Page::Profile::PersonalAccessTokens.perform do |page|
          page.fill_token_name(name || 'api-test-token')
          page.check_api
          page.create_token
        end
      end
    end
  end
end
