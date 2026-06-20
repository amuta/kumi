# frozen_string_literal: true

require "tmpdir"

# First-class error reporting for the Ruby frontend: errors raised while loading
# a `.rb` schema should render `file:line: message` plus a caret code-frame, the
# same shape the text frontend produces, and common syntax mistakes should get
# actionable messages rather than leaking raw Ruby errors.
RSpec.describe "Ruby frontend error reporting" do
  def load_error(src)
    Dir.mktmpdir("ruby_errors") do |dir|
      path = File.join(dir, "schema.rb")
      File.write(path, src)
      begin
        Kumi::Frontends::Ruby.load(path: path)
        nil
      rescue StandardError => e
        e.message
      end
    end
  end

  it "renders a located header and code frame for syntax errors" do
    msg = load_error(<<~RUBY)
      schema do
        trait "x", input.a > 1
      end
    RUBY

    expect(msg).to match(/schema\.rb:2: /)
    expect(msg).to include("The name for 'trait' must be a Symbol")
    expect(msg).to include("➤")
    expect(msg).to include('trait "x"')
  end

  it "does not duplicate the location in the message" do
    msg = load_error(<<~RUBY)
      schema do
        trait "x", input.a > 1
      end
    RUBY

    expect(msg.scan(/line=\d+ column=\d+/)).to be_empty
    expect(msg).not_to match(/:\d+:\d+:/)
  end

  it "gives a first-class error for an unknown DSL keyword" do
    msg = load_error(<<~RUBY)
      schema do
        bogus_keyword :foo
      end
    RUBY

    expect(msg).to include("unknown DSL keyword `bogus_keyword`")
    expect(msg).to include("Valid top-level keywords")
  end

  it "explains literal-left comparisons in method scope instead of leaking a coerce error" do
    msg = load_error(<<~RUBY)
      class Foo
        extend Kumi::Schema
        def self.build_it
          schema do
            input do
              integer :age
            end
            trait :old, (80 <= input.age)
          end
        end
      end
      Foo.build_it
    RUBY

    expect(msg).to include("literal-on-the-left")
    expect(msg).to include("input.age >= 80")
    expect(msg).not_to include("coerce")
    expect(msg).not_to include("undefined method")
  end

  it "explains uppercase declaration references instead of leaking a constant error" do
    msg = load_error(<<~RUBY)
      schema do
        input do
          integer :a
        end
        let :W, input.a
        value :b, W + 1
      end
    RUBY

    expect(msg).to include("`W`")
    expect(msg).to include("uppercase")
    expect(msg).to include("ref(:W)")
    expect(msg).not_to include("uninitialized constant")
  end
end
