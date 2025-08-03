require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe "JavaScript Size Benchmark", :js do
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.rm_rf(temp_dir)
  end

  def create_schema_class(name, inputs_count:, traits_count:, values_count:, cascade_depth: 0)
    Class.new do
      extend Kumi::Schema
      
      schema do
        input do
          (1..inputs_count).each do |i|
            case i % 4
            when 0
              integer "field_#{i}".to_sym, domain: 1..100
            when 1
              string "name_#{i}".to_sym
            when 2
              float "amount_#{i}".to_sym, domain: 0.0..1000.0
            when 3
              boolean "flag_#{i}".to_sym
            end
          end
        end
        
        (1..traits_count).each do |i|
          # Use round-robin to find an appropriate field based on what exists
          field_idx = ((i - 1) % inputs_count) + 1
          case field_idx % 4
          when 0  # integer field
            trait "trait_#{i}".to_sym, (input.send("field_#{field_idx}") > 50)
          when 1  # string field  
            trait "trait_#{i}".to_sym, (input.send("name_#{field_idx}") == "Test Name #{field_idx}")
          when 2  # float field
            trait "trait_#{i}".to_sym, (input.send("amount_#{field_idx}") >= 100.0)
          when 3  # boolean field
            trait "trait_#{i}".to_sym, (input.send("flag_#{field_idx}") == true)
          end
        end
        
        (1..values_count).each do |i|
          if i <= cascade_depth
            value "cascade_value_#{i}".to_sym do
              (1..[traits_count, 3].min).each do |j|
                on send("trait_#{j}"), "Result_#{j}_for_#{i}"
              end
              base "Default_#{i}"
            end
          else
            case i % 4
            when 0
              value "computed_#{i}".to_sym, fn(:add, input.send("field_#{[i, inputs_count].min}"), input.send("amount_#{[i, inputs_count].min}"))
            when 1
              value "multiplied_#{i}".to_sym, fn(:multiply, input.send("amount_#{[i, inputs_count].min}"), 1.5)
            when 2
              value "comparison_#{i}".to_sym, fn(:>, input.send("amount_#{[i, inputs_count].min}"), 50.0)
            when 3
              value "conditional_#{i}".to_sym, fn(:clamp, input.send("field_#{[i, inputs_count].min}"), 10, 90)
            end
          end
        end
      end
      
      define_singleton_method(:name) { name }
    end
  end

  def measure_js_size(schema_class, label)
    js_code = Kumi::Js.compile(schema_class)
    
    file_path = File.join(temp_dir, "#{label.downcase.gsub(/\s+/, '_')}.js")
    File.write(file_path, js_code)
    
    size = js_code.bytesize
    lines = js_code.lines.count
    
    {
      label: label,
      size_bytes: size,
      size_kb: (size / 1024.0).round(2),
      lines: lines,
      file_path: file_path
    }
  end

  it "measures JavaScript output size for various schema complexities" do
    results = []
    
    # Tiny schema
    tiny_schema = create_schema_class("TinySchema", 
      inputs_count: 3, 
      traits_count: 2, 
      values_count: 3
    )
    results << measure_js_size(tiny_schema, "Tiny (3 inputs, 2 traits, 3 values)")
    
    # Small schema
    small_schema = create_schema_class("SmallSchema",
      inputs_count: 10,
      traits_count: 8,
      values_count: 12
    )
    results << measure_js_size(small_schema, "Small (10 inputs, 8 traits, 12 values)")
    
    # Medium schema
    medium_schema = create_schema_class("MediumSchema",
      inputs_count: 25,
      traits_count: 20,
      values_count: 30,
      cascade_depth: 5
    )
    results << measure_js_size(medium_schema, "Medium (25 inputs, 20 traits, 30 values, 5 cascades)")
    
    # Large schema
    large_schema = create_schema_class("LargeSchema",
      inputs_count: 50,
      traits_count: 40,
      values_count: 60,
      cascade_depth: 10
    )
    results << measure_js_size(large_schema, "Large (50 inputs, 40 traits, 60 values, 10 cascades)")
    
    # Very large schema
    xlarge_schema = create_schema_class("XLargeSchema",
      inputs_count: 100,
      traits_count: 80,
      values_count: 120,
      cascade_depth: 20
    )
    results << measure_js_size(xlarge_schema, "XLarge (100 inputs, 80 traits, 120 values, 20 cascades)")
    
    # Massive schema
    massive_schema = create_schema_class("MassiveSchema",
      inputs_count: 200,
      traits_count: 150,
      values_count: 250,
      cascade_depth: 30
    )
    results << measure_js_size(massive_schema, "Massive (200 inputs, 150 traits, 250 values, 30 cascades)")
    
    puts "\n" + "="*80
    puts "JavaScript Size Benchmark Results"
    puts "="*80
    puts "%-60s %10s %8s %8s" % ["Schema Complexity", "Size (KB)", "Lines", "Bytes"]
    puts "-"*80
    
    results.each do |result|
      puts "%-60s %10.2f %8d %8d" % [
        result[:label], 
        result[:size_kb], 
        result[:lines],
        result[:size_bytes]
      ]
    end
    
    puts "-"*80
    puts "Files generated in: #{temp_dir}"
    puts "="*80
    
    # Verify all schemas compile without errors
    results.each do |result|
      expect(result[:size_bytes]).to be > 0
      expect(File.exist?(result[:file_path])).to be true
    end
    
    # Check scaling relationship
    expect(results.last[:size_kb]).to be > results.first[:size_kb] * 5
    
    # Analyze growth patterns
    puts "\nGrowth Analysis:"
    results.each_cons(2) do |prev, curr|
      growth_factor = (curr[:size_kb] / prev[:size_kb]).round(2)
      puts "#{prev[:label]} -> #{curr[:label]}: #{growth_factor}x growth"
    end
  end
  
  it "measures runtime performance of generated JavaScript" do
    # Create a moderate complexity schema for runtime testing
    runtime_schema = create_schema_class("RuntimeSchema",
      inputs_count: 30,
      traits_count: 25, 
      values_count: 40,
      cascade_depth: 8
    )
    
    js_code = Kumi::Js.compile(runtime_schema)
    
    # Write test file with performance measurement
    test_file = File.join(temp_dir, "runtime_test.js")
    File.write(test_file, <<~JS)
      #{js_code}
      
      // Generate test data
      const testData = {
        #{(1..30).map { |i|
          case i % 4
          when 0
            "field_#{i}: #{rand(1..100)}"
          when 1  
            "name_#{i}: 'Test Name #{i}'"
          when 2
            "amount_#{i}: #{rand(0.0..1000.0).round(2)}"
          when 3
            "flag_#{i}: #{[true, false].sample}"
          end
        }.join(",\n        ")}
      };
      
      console.log("Generated JS size:", #{js_code.bytesize}, "bytes");
      console.log("Generated JS lines:", #{js_code.lines.count});
      
      // Performance test
      const iterations = 1000;
      const start = Date.now();
      
      for (let i = 0; i < iterations; i++) {
        const runner = schema.from(testData);
        // Test a few simple calculations that we know exist
        const trait1 = runner.fetch('trait_1');
        const trait2 = runner.fetch('trait_2');  
        const cascade1 = runner.fetch('cascade_value_1');
      }
      
      const end = Date.now();
      const duration = end - start;
      
      console.log("Runtime performance:");
      console.log(`${iterations} iterations in ${duration}ms`);
      console.log(`Average: ${(duration / iterations).toFixed(3)}ms per execution`);
      console.log(`Throughput: ${(iterations / (duration / 1000)).toFixed(0)} executions/second`);
    JS
    
    # Run the JavaScript performance test
    result = `node "#{test_file}" 2>&1`
    
    puts "\n" + "="*60
    puts "JavaScript Runtime Performance Test"
    puts "="*60
    puts result
    puts "="*60
    
    expect(result).to include("Generated JS size:")
    expect(result).to include("Runtime performance:")
  end
end