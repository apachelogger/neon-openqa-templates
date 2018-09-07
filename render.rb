require 'fileutils'
require 'json'
require 'yaml'

class SettingsConverter
  def initialize(obj)
    @obj = obj
  end

  def convert
    convert_by_type(@obj)
  end

  def convert_by_type(o)
    case o
    when String, Integer
      return o
    when Hash
      return convert_h(o)
    when Array
      return convert_a(o)
    end
    raise "Unknown type --> #{o} [#{o.class}]"
  end

  def convert_h(o)
    o.each_with_object({}) do |(k, v), hash|
      hash[k] = k == 'settings' ? convert_settings(v) : convert_by_type(v)
    end
  end

  def convert_a(o)
    o.each_with_object([]) do |v, array|
      array << convert_by_type(v)
    end
  end

  def convert_settings(o)
    o.each_with_object([]) do |(k, v), array|
      array << { key: k, value: v }
    end
  end
end

def load_yaml(file_name)
  data = YAML.load_file(File.join(__dir__, 'templates', file_name))
  SettingsConverter.new(data).convert
end

unless ENV.include?('IN_FORK')
  puts 'not in fork'
  Dir.chdir(__dir__)
  exec({ IN_FORK: 1 }, 'ruby', __FILE__, ARGV) if system('git pull --rebase')
  raise
else
  puts 'in fork'
end

templates = {}
templates['JobTemplates'] = load_yaml('job_templates.yaml')
templates['Machines'] = load_yaml('machines.yaml')
templates['Products'] = load_yaml('products.yaml')
templates['TestSuites'] = load_yaml('test_suites.yaml')

script = <<-SCRIPT_HEADER
#!/bin/sh
#
# use load_templates to load the file into the database
#
# This script is auto-generated from openqa/templates/*.yaml. Any changes here
# get discarded.
/usr/share/openqa/script/load_templates "$@" templates.json
SCRIPT_HEADER
File.write('templates', script)
FileUtils.chmod(0o744, 'templates')

json = JSON.pretty_generate(templates)
File.write('templates.json', json)
puts json
