# IRBRC file by Iain Hecker, http://iain.nl
# put all this in your ~/.irbrc

# if defined?(Order)
#   Order.instance_eval do
#     def devour(number)
#       find_by!(number: number)
#     end
#   end
# end

# if defined?(DpdLabel)
#   DpdLabel.instance_eval do
#     def devour(number)
#       find_by!(waybill: number)
#     end
#   end
# end

# class Array
#   def pretty
#     map do |args|
#       [*args[0..-2], format("%6.2f%%", args.last)]
#     end
#   end

#   def percent
#     total = sum { |args| args.last }

#     map do |args|
#       [*args, (args.last * 100.to_f / total).round(2)]
#     end
#   end

#   def top(limit = nil)
#     result = sort_by(&:last).reverse

#     if limit
#       result.first(limit)
#     else
#       result
#     end
#   end
# end

# class Hash
#   def grep_keys(regexp)
#     select do |key, _|
#       key =~ regexp
#     end
#   end

#   def grep_values(regexp)
#     select do |_, value|
#       value =~ regexp
#     end
#   end

#   def grep(regexp)
#     select do |key, value|
#       key =~ regexp || value =~ regexp
#     end
#   end
# end

# begin
#   require "irbtools"
# rescue LoadError
# end

require "rubygems"
require "yaml"
require "pp"
require "irb/completion"
require "irb/ext/save-history"

# History configuration

IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = "#{ENV["HOME"]}/.irb-save-history"
IRB.conf[:USE_MULTILINE] = false

def jpp(data)
  values =
    if data.is_a? String
      JSON.parse(data)
    else
      data
    end
  puts JSON.pretty_generate(values)
end

def tpp(data, limit: nil)
  require "terminal-table"

  wrapped =
    if data.first.is_a?(Array) || data.first.is_a?(Hash)
      data
    else
      [data]
    end

  table_data =
    if limit
      wrapped.map do |key, value|
        [key.to_s[0..limit], value.to_s[0..limit]]
      end
    else
      wrapped
    end

  puts Terminal::Table.new(rows: table_data)
rescue LoadError
  "Missing terminal table extendsion"
end

alias q exit

class Object
  def local_methods
    (methods - Object.instance_methods).sort
  end
end

ANSI = {}
ANSI[:RESET]     = "\e[0m"
ANSI[:BOLD]      = "\e[1m"
ANSI[:UNDERLINE] = "\e[4m"
ANSI[:LGRAY]     = "\e[0;37m"
ANSI[:GRAY]      = "\e[1;30m"
ANSI[:RED]       = "\e[31m"
ANSI[:GREEN]     = "\e[32m"
ANSI[:YELLOW]    = "\e[33m"
ANSI[:BLUE]      = "\e[34m"
ANSI[:MAGENTA]   = "\e[35m"
ANSI[:CYAN]      = "\e[36m"
ANSI[:WHITE]     = "\e[37m"


def color(color, string)
  ANSI[color] + string + ANSI[:RESET]
end

# Build a simple colorful IRB prompt

if defined? Rails
  shortcuts = {
    "Callmeapp" => color(:YELLOW, "CRM"),
  }

  envs = {
    "development" => color(:BLUE, "devel"),
    "production" => color(:RED, "prod"),
    "test" => color(:BLUE, "test"),
  }

  env = envs.fetch(Rails.env)

  klass_name =
    if Rails.application.class.respond_to?(:module_parent)
      Rails.application.class.module_parent.to_s
    else
      Rails.application.class.parent.to_s
    end

  name = shortcuts.fetch(klass_name, klass_name)
  version = RUBY_VERSION

  IRB.conf[:PROMPT][:SIMPLE_COLOR] = {
    :PROMPT_I => "#{name} [#{env}] #{version} >> ",
    :PROMPT_C => "#{name} [#{env}] #{version} >> ",
    :PROMPT_S => "#{name} [#{env}] #{version} >> ",
    :PROMPT_N => "#{name} [#{env}] #{version} >> ",
    :RETURN   => "#{ANSI[:GREEN]}=>#{ANSI[:RESET]} %s\n",
    :AUTO_INDENT => false,
  }

  IRB.conf[:PROMPT_MODE] = :SIMPLE_COLOR
end

def wrap_color(color, string)
  format(
    "%<color>s%<string>s%<reset>s",
    color: ANSI.fetch(color),
    string: string,
    reset: ANSI.fetch(:RESET),
  )
end

# Loading extensions of the console. This is wrapped
# because some might not be included in your Gemfile
# and errors will be raised
def extend_console(name, care = true, required = true)
  $console_extensions ||= []
  if care
    require name if required
    yield if block_given?
    $console_extensions << wrap_color(:GREEN, name)
  else
    $console_extensions << wrap_color(:GRAY, name)
  end
rescue LoadError
  $console_extensions << wrap_color(:RED, name)
end

# extend_console "brice" do
#   Brice.init do |config|
#     config.history.opt = {
#       size: 10_000,
#       merge: true,
#       path: "#{ENV['HOME']}/.irb_saved_history",
#     }
#   end
# end

# Wirble is a gem that handles coloring the IRB
# output and history
# extend_console 'wirble' do
#   Wirble.init
#   Wirble.colorize
# end

extend_console "sidekiq/api"

extend_console "highline" do
  Signal.trap("SIGWINCH", proc {
    Hirb::View.resize *HighLine.new.terminal.terminal_size
  })
end

# Hirb makes tables easy.
extend_console "hirber" do
  Hirb.enable
  extend Hirb::Console

  def tu(*args, **kwargs)
    table *args, **kwargs.merge(unicode: true)
  end

  def tuh(*args, **kwargs)
    table *args, **kwargs.reverse_merge(unicode: true, headers: nil)
  end

  %w[ActiveRecord::Base Hash Array].each do |klass|
    Hirb::Formatter
      .dynamic_config[klass] = {
        class: Hirb::Helpers::AutoTable,
        ancestor: true,
        options: { unicode: true },
      }
  end
end

# awesome_print is prints prettier than pretty_print
extend_console 'ap' do
  alias pp ap
end

# When you're using Rails 2 console, show queries in the console
extend_console 'rails2', (ENV.include?('RAILS_ENV') && !Object.const_defined?('RAILS_DEFAULT_LOGGER')), false do
  require 'logger'
  RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
end

# When you're using Rails 3 console, show queries in the console
extend_console 'rails3', defined?(ActiveSupport::Notifications), false do
  $odd_or_even_queries = false
  ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
    $odd_or_even_queries = !$odd_or_even_queries
    color = $odd_or_even_queries ? ANSI[:CYAN] : ANSI[:MAGENTA]
    event = ActiveSupport::Notifications::Event.new(*args)
    time  = "%.1fms" % event.duration
    name  = event.payload[:name]
    sql   = event.payload[:sql].gsub("\n", " ").squeeze(" ")
    puts "  #{ANSI[:UNDERLINE]}#{color}#{name} (#{time})#{ANSI[:RESET]}  #{sql}"
  end
end

# Add a method pm that shows every method on an object
# Pass a regex to filter these
extend_console 'pm', true, false do
  def pm(obj, *options) # Print methods
    methods = obj.methods
    methods -= Object.methods unless options.include? :more
    filter  = options.select {|opt| opt.kind_of? Regexp}.first
    methods = methods.select {|name| name =~ filter} if filter

    data = methods.sort.collect do |name|
      method = obj.method(name)
      if method.arity == 0
        args = "()"
      elsif method.arity > 0
        n = method.arity
        args = "(#{(1..n).collect {|i| "arg#{i}"}.join(", ")})"
      elsif method.arity < 0
        n = -method.arity
        args = "(#{(1..n).collect {|i| "arg#{i}"}.join(", ")}, ...)"
      end
      klass = $1 if method.inspect =~ /Method: (.*?)#/
      [name.to_s, args, klass]
    end
    max_name = data.collect {|item| item[0].size}.max
    max_args = data.collect {|item| item[1].size}.max
    data.each do |item|
      print " #{ANSI[:YELLOW]}#{item[0].to_s.rjust(max_name)}#{ANSI[:RESET]}"
      print "#{ANSI[:BLUE]}#{item[1].ljust(max_args)}#{ANSI[:RESET]}"
      print "   #{ANSI[:GRAY]}#{item[2]}#{ANSI[:RESET]}\n"
    end
    data.size
  end
end

extend_console 'interactive_editor' do
  # no configuration needed
end

# Show results of all extension-loading
puts "#{ANSI[:GRAY]}~> Console extensions:#{ANSI[:RESET]} #{$console_extensions.join(' ')}#{ANSI[:RESET]}"
