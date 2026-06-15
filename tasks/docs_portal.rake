# frozen_string_literal: true

require "json"
require "fileutils"
require "shellwords"
require "English"

# Generates the documentation-portal artifacts consumed by the kumi-docs site:
# the function reference, per-stage pipeline transformations for a curated set
# of teaching schemas, and one page per golden example.
module DocsPortal
  ROOT = File.expand_path("..", __dir__)
  OUT  = File.join(ROOT, "tmp", "docs-artifacts")
  KUMI = File.join(ROOT, "bin", "kumi")

  # Stages rendered for each teaching schema, in pipeline order. Each entry is
  # [repr passed to `bin/kumi pp`, title, fenced-code language, one-line intro].
  STAGES = [
    ["ast",               "AST",                "text", "Parser output, still close to the source `schema do … end`."],
    ["input_plan",        "Input plan",         "text", "How declared inputs are traversed and accessed."],
    ["nast",              "NAST",               "text", "Normalized AST: frontend irregularity removed, constants folded."],
    ["snast",             "SNAST",              "text", "Semantic AST stamped with dimensional and type metadata."],
    ["dfir",              "DFIR",               "text", "First graph-shaped layer: dataflow, access paths, inlined imports."],
    ["dfir_optimized",    "DFIR (optimized)",   "text", "After CSE, dedup, and broadcast cleanup."],
    ["vecir",             "VecIR",              "text", "Axis-aware value semantics; every value stamped with axes + dtype."],
    ["loopir",            "LoopIR",             "text", "Execution layer: explicit loop nests, accumulators, indexed reads."],
    ["schema_ruby",       "Emitted Ruby",       "ruby", "Final dependency-free Ruby emitted from LoopIR."],
    ["schema_javascript", "Emitted JavaScript", "javascript", "The same schema emitted as JavaScript with identical semantics."]
  ].freeze

  # Curated teaching schemas, smallest-first, a reader can follow while ramping up.
  TEACHING_SCHEMAS = %w[simple_math array_operations outer_let game_of_life].freeze

  module_function

  def title(slug)
    slug.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  def render(repr, schema)
    out = `#{KUMI.shellescape} pp #{repr.shellescape} #{schema.shellescape} 2>&1`
    return out if $?.success?

    "# could not render #{repr} for #{schema}\n#{out}"
  end

  def functions
    require File.join(ROOT, "lib", "kumi")
    loader = Kumi::DocGenerator::Loader.new(
      functions_dir: File.join(ROOT, "data", "functions"),
      kernels_dir: File.join(ROOT, "data", "kernels", "ruby")
    )
    docs = Kumi::DocGenerator::Merger.new(loader).merge
    write("reference/functions.md", Kumi::DocGenerator::Formatters::Markdown.new(docs).format)
    puts "✓ functions.md (#{docs.keys.uniq.size} aliases)"
  end

  def pipeline
    index = ["# Worked transformations", "",
             "Each schema below is shown descending through every compiler layer, " \
             "from the parsed AST down to emitted Ruby and JavaScript. Read one " \
             "schema top-to-bottom to see how Kumi transforms it.", ""]

    TEACHING_SCHEMAS.each do |name|
      schema = File.join(ROOT, "golden", name, "schema.kumi")
      next warn("  ! skipping #{name}: no golden schema") unless File.exist?(schema)

      pipeline_schema(name, schema)
      index << "- [#{title(name)}](#{name}/index.md)"
    end

    write("reference/pipeline/index.md", "#{index.join("\n")}\n")
  end

  def pipeline_schema(name, schema)
    source = File.read(schema).strip
    overview = ["# #{title(name)}", "", "```ruby", source, "```", "",
                "This schema passes through the following stages:", ""]
    STAGES.each { |repr, t, _lang, intro| overview << "- [#{t}](#{repr}.md) — #{intro}" }
    write("reference/pipeline/#{name}/index.md", "#{overview.join("\n")}\n")

    STAGES.each_with_index do |(repr, t, lang, intro), i|
      page = ["# #{t}", "", "> Schema: [`#{name}`](index.md) · Stage #{i + 1} of #{STAGES.size}", "",
              intro, "", "```#{lang}", render(repr, schema).rstrip, "```", ""]
      write("reference/pipeline/#{name}/#{repr}.md", page.join("\n"))
    end
    puts "✓ pipeline/#{name} (#{STAGES.size} stages)"
  end

  def examples
    names = Dir[File.join(ROOT, "golden", "*", "schema.kumi")]
            .map { |p| File.basename(File.dirname(p)) }
            .reject { |n| n.start_with?("_") }.sort

    index = ["# Examples", "",
             "Every schema in the golden suite, runnable as-is. Schemas marked with " \
             "a 🔬 also have a full " \
             "[worked transformation](../reference/generated/pipeline/index.md).", ""]

    names.each do |name|
      worked = TEACHING_SCHEMAS.include?(name)
      example_page(name, worked)
      index << "- [#{title(name)}](#{name}.md)#{' 🔬' if worked}"
    end

    write("examples/index.md", "#{index.join("\n")}\n")
    puts "✓ examples (#{names.size} schemas)"
  end

  def example_page(name, worked)
    source = File.read(File.join(ROOT, "golden", name, "schema.kumi")).strip
    page = ["# #{title(name)}", ""]
    page += ["> 🔬 See the [full pipeline walkthrough](../reference/generated/pipeline/#{name}/index.md).", ""] if worked
    page += ["```ruby", source, "```", ""]
    write("examples/#{name}.md", page.join("\n"))
  end

  def write(rel, body)
    path = File.join(OUT, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
  end
end

namespace :docs do
  desc "Generate the documentation-portal artifacts into tmp/docs-artifacts/"
  task :portal do
    FileUtils.rm_rf(DocsPortal::OUT)
    FileUtils.mkdir_p(DocsPortal::OUT)
    DocsPortal.functions
    DocsPortal.pipeline
    DocsPortal.examples
    puts "\n✓ Portal artifacts written to #{DocsPortal::OUT}"
  end
end
