# frozen_string_literal: true

require "spec_helper"
require_relative "../support/analyzer_state_helper"

RSpec.describe "Hierarchical Broadcasting Golden Test" do
  include AnalyzerStateHelper

  it "validates dimensional analysis up to function signature pass" do
    # Golden test: Complex hierarchical schema should fail at FunctionSignaturePass
    # with correct dimensional shape detection, proving Step 1 metadata-driven approach works

    expect do
      analyze_up_to(:function_signatures) do
        input do
          array :regions do
            array :offices do
              array :teams do
                float :performance_score
                array :employees do
                  float :salary
                  float :rating
                  string :level
                end
              end
            end
          end
        end

        # Employee-level traits
        trait :high_performer, input.regions.offices.teams.employees.rating >= 4.5
        trait :senior_level, input.regions.offices.teams.employees.level == "senior"

        # Team-level trait (parent dimension)
        trait :top_team, input.regions.offices.teams.performance_score >= 0.9

        value :employee_bonus do
          on high_performer, senior_level, top_team,
             input.regions.offices.teams.employees.salary * 0.30
          on high_performer, top_team,
             input.regions.offices.teams.employees.salary * 0.20
          base input.regions.offices.teams.employees.salary * 0.05
        end
      end
    end
  end
end
