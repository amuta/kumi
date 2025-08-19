# frozen_string_literal: true
require "spec_helper"
require_relative "../golden/golden_helper"
require_relative "../support/analyzer_state_helper"

RSpec.describe "Pre-Lower invariants (Step 1)", :prelower do
  include GoldenHelper
  include AnalyzerStateHelper

  let(:schema_block) do
    proc do
      input do
        array :companies do
          string :name
          hash :hr_info do
            string :policy
            array :employees do
              integer :hours
              string  :level
              hash :personal_info do
                string :email
                array :projects do
                  string  :title
                  integer :priority
                end
              end
            end
          end
        end
      end

      # Values used by tests
      value :employee_hours, input.companies.hr_info.employees.hours
      value :project_priorities, input.companies.hr_info.employees.personal_info.projects.priority

      # Reductions we want to verify
      value :total_hours_per_company, fn(:sum, input.companies.hr_info.employees.hours)
      value :avg_priority_per_employee, fn(:mean, input.companies.hr_info.employees.personal_info.projects.priority)
    end
  end

  let(:data) do
    {
      companies: [
        {
          name: "TechCorp",
          hr_info: {
            policy: "flexible",
            employees: [
              { hours: 40, level: "senior",
                personal_info: { email: "alice@techcorp.com",
                                  projects: [ {title:"WebApp", priority:9}, {title:"API", priority:7} ] } },
              { hours: 30, level: "junior",
                personal_info: { email: "bob@techcorp.com",
                                  projects: [ {title:"Tests",  priority:5} ] } }
            ]
          }
        },
        {
          name: "DataCorp",
          hr_info: {
            policy: "remote",
            employees: [
              { hours: 45, level: "senior",
                personal_info: { email: "carol@datacorp.com",
                                  projects: [ {title:"ML", priority:10}, {title:"Dash", priority:6} ] } }
            ]
          }
        }
      ]
    }
  end

  it "uses array-boundaries-only semantic axes for inputs" do
    state = analyze_until_join_reduce(schema_block, data)

    input_metadata = state[:input_metadata]

    expect(dims_from_path(%i[companies hr_info employees hours], input_metadata)).to eq(%i[companies employees])
    expect(dims_from_path(%i[companies hr_info employees personal_info projects priority], input_metadata))
      .to eq(%i[companies employees projects])

    # No hash hops in any decl shape or inferred node scope
    bad = []
    (state[:decl_shapes] || {}).each do |name, sh|
      bad << [name, sh[:scope]] if sh[:scope].intersect?(%i[hr_info personal_info])
    end
    (state[:node_index] || {}).each_value do |m|
      sc = m[:inferred_scope] || []
      bad << [m, sc] if sc.intersect?(%i[hr_info personal_info])
    end
    expect(bad).to be_empty, "Found hash segments treated as axes: #{bad.inspect}"
  end

  it "plans reducers with correct axis and target_scope (array-only)" do
    state = analyze_until_join_reduce(schema_block, data)

    # Find the call nodes by declaration name
    declarations = state[:declarations] || {}
    total_hours_decl = declarations[:total_hours_per_company]
    avg_priority_decl = declarations[:avg_priority_per_employee]

    expect(total_hours_decl).to be_truthy, "missing total_hours_per_company declaration"
    expect(avg_priority_decl).to be_truthy, "missing avg_priority_per_employee declaration"

    # Find their call expressions in node_index
    node_index = state[:node_index] || {}
    
    th_call_node = nil
    ap_call_node = nil
    
    node_index.each do |oid, metadata|
      if metadata[:expression_node]&.class&.name&.include?("CallExpression")
        if metadata[:expression_node]&.fn_name == :sum
          th_call_node = metadata
        elsif metadata[:expression_node]&.fn_name == :mean
          ap_call_node = metadata
        end
      end
    end

    expect(th_call_node).to be_truthy, "missing sum call node"
    expect(ap_call_node).to be_truthy, "missing mean call node"

    th_plan = th_call_node[:join_plan]
    ap_plan = ap_call_node[:join_plan]

    # sum over employees -> companies
    expect(th_plan[:policy]).to eq(:reduce)
    expect(th_plan[:axis]).to eq([:employees])
    expect(th_plan[:target_scope]).to eq([:companies])

    # mean over projects -> employees within companies
    expect(ap_plan[:policy]).to eq(:reduce)
    expect(ap_plan[:axis]).to eq([:projects])
    expect(ap_plan[:target_scope]).to eq([:companies, :employees])

    # guard: axes must be array-boundary names only
    expect(th_plan[:axis] & [:hr_info, :personal_info]).to be_empty
    expect(ap_plan[:axis] & [:hr_info, :personal_info]).to be_empty
  end

  it "feeds FunctionSignature/Ambiguity with correct input shapes (no prefixes)" do
    state = analyze_until_join_reduce(schema_block, data)

    node_index = state[:node_index] || {}
    
    sum_node = nil
    mean_node = nil
    
    node_index.each do |oid, metadata|
      if metadata[:expression_node]&.class&.name&.include?("CallExpression")
        if metadata[:expression_node]&.fn_name == :sum
          sum_node = metadata
        elsif metadata[:expression_node]&.fn_name == :mean
          mean_node = metadata
        end
      end
    end

    expect(sum_node&.dig(:selected_signature, :dropped_axes)).to eq([:employees])
    expect(mean_node&.dig(:selected_signature, :dropped_axes)).to eq([:projects])
  end
end