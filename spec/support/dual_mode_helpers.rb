# frozen_string_literal: true

module DualModeHelpers
  # RSpec helper to enable dual mode for a test block
  def with_dual_mode(&block)
    if node_available?
      DualRunner.with_dual_mode(&block)
    else
      skip "Node.js not available for dual mode testing"
    end
  end

  # RSpec helper to enable dual mode with debug output
  def with_dual_mode_debug(&block)
    if node_available?
      DualRunner.with_dual_mode do
        DualRunner.with_debug(&block)
      end
    else
      skip "Node.js not available for dual mode testing"
    end
  end

  # RSpec helper to enable dual mode with metrics but no debug output
  def with_dual_mode_silent(&block)
    if node_available?
      DualRunner.with_dual_mode(&block)
    else
      skip "Node.js not available for dual mode testing"
    end
  end

  # RSpec helper to enable dual mode for entire describe/context blocks
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def with_dual_mode_enabled(&block)
      around do |example|
        if node_available?
          DualRunner.with_dual_mode { example.run }
        else
          skip "Node.js not available for dual mode testing"
        end
      end

      instance_eval(&block)
    end

    def dual_mode_example(description, &block)
      it description do
        with_dual_mode(&block)
      end
    end

    def dual_mode_debug_example(description, &block)
      it description do
        with_dual_mode_debug(&block)
      end
    end
  end

  private

  def node_available?
    @node_available ||= begin
      _, _, status = Open3.capture3("node", "--version")
      status.success?
    rescue Errno::ENOENT
      false
    end
  end
end
