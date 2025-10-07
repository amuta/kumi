# frozen_string_literal: true

require "fileutils"

module Kumi
  module Core
    module Analyzer
      module Checkpoint
        class << self
          # ===== Interface shape matches Debug =====
          def enabled?
            return false if ENV["KUMI_CHECKPOINT"] == "0"

            ENV["KUMI_CHECKPOINT"] == "1" ||
              !resume_from.nil? || !resume_at.nil? || !stop_after.nil?
          end

          # ---- Config (ENV) ----
          def dir         = ENV["KUMI_CHECKPOINT_DIR"]    || "tmp/analysis_snapshots"
          def phases      = (ENV["KUMI_CHECKPOINT_PHASE"] || "before,after").split(",").map! { _1.strip.downcase.to_sym }
          def formats     = (ENV["KUMI_CHECKPOINT_FORMAT"] || "marshal").split(",").map! { _1.strip.downcase } # marshal|json|both
          def resume_from = ENV.fetch("KUMI_RESUME_FROM", nil) # file path (.msh or .json)
          def resume_at   = ENV.fetch("KUMI_RESUME_AT", nil)   # pass short name
          def stop_after  = ENV.fetch("KUMI_STOP_AFTER", nil)  # pass short name

          # ===== Lifecycle (called by analyzer) =====
          def load_initial_state(default_state)
            path = resume_from
            return default_state unless path && File.exist?(path)

            data = File.binread(path)
            if path.end_with?(".msh")
              StateSerde.load_marshal(data)
            else
              StateSerde.load_json(data)
            end
          end

          def entering(pass_name:, idx:, state:)
            return unless enabled?

            snapshot(pass_name:, idx:, phase: :before, state:) if phases.include?(:before)
          end

          def leaving(pass_name:, idx:, state:)
            return unless enabled?

            snapshot(pass_name:, idx:, phase: :after, state:) if phases.include?(:after)
          end

          # ===== Implementation =====
          def snapshot(pass_name:, idx:, phase:, state:)
            FileUtils.mkdir_p(dir)
            base = File.join(dir, "%03d_#{pass_name}_#{phase}" % idx)
            files = []

            if formats.include?("marshal") || formats.include?("both")
              path = "#{base}.msh"
              File.binwrite(path, StateSerde.dump_marshal(state))
              files << path
            end

            if formats.include?("json") || formats.include?("both")
              path = "#{base}.json"
              File.write(path, StateSerde.dump_json(state, pretty: true))
              files << path
            end

            # Fold checkpoint info into the same per-pass logs the Debugger uses.
            Core::Analyzer::Debug.info(:checkpoint, phase:, idx:, files:) if Core::Analyzer::Debug.enabled?

            files
          end
        end
      end
    end
  end
end
