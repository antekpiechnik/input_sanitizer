require 'input_sanitizer/restricted_hash'
require 'input_sanitizer/default_converters'

class InputSanitizer::Sanitizer
  def initialize(data)
    @data = symbolize_keys(data)
    @performed = false
    @errors = []
    @cleaned = InputSanitizer::RestrictedHash.new(self.class.fields.keys)
  end

  def self.clean(data={})
    return InputSanitizer::RestrictedHash.new([]) if data.nil?
    new(data).cleaned
  end

  def [](field)
    cleaned[field]
  end

  def cleaned
    return @cleaned if @performed
    self.class.fields.each do |field, hash|
      type = hash[:type]
      required = hash[:options][:required]
      clean_field(field, type, required)
    end
    @performed = true
    @cleaned.freeze
  end

  def valid?
    cleaned
    @errors.empty?
  end

  def errors
    cleaned
    @errors
  end

  def self.converters
    {
      :integer => InputSanitizer::IntegerConverter.new,
      :string => InputSanitizer::StringConverter.new,
      :date => InputSanitizer::DateConverter.new,
      :time => InputSanitizer::TimeConverter.new,
      :boolean => InputSanitizer::BooleanConverter.new,
    }
  end

  def self.inherited(subclass)
    subclass.fields = self.fields.dup
  end

  def self.string(*keys)
    set_keys_to_type(keys, :string)
  end

  def self.integer(*keys)
    set_keys_to_type(keys, :integer)
  end

  def self.boolean(*keys)
    set_keys_to_type(keys, :boolean)
  end

  def self.date(*keys)
    set_keys_to_type(keys, :date)
  end

  def self.time(*keys)
    set_keys_to_type(keys, :time)
  end

  def self.custom(*keys)
    options = keys.pop
    converter = options.delete(:converter)
    keys.push(options)
    raise "You did not define a converter for a custom type" if converter == nil
    self.set_keys_to_type(keys, converter)
  end

  protected
  def self.fields
    @fields ||= {}
  end

  def self.fields=(new_fields)
    @fields = new_fields
  end

  private
  def self.extract_options!(array)
    array.last.is_a?(Hash) ? array.pop : {}
  end

  def self.extract_options(array)
    array.last.is_a?(Hash) ? array.last : {}
  end

  def clean_field(field, type, required)
    if @data.has_key?(field)
      begin
        @cleaned[field] = convert(field, type)
      rescue InputSanitizer::ConversionError => ex
        add_error(field, :invalid_value, @data[field], ex.message)
      end
    elsif required
      add_missing(field)
    end
  end

  def add_error(field, error_type, value, description = nil)
    @errors << {
      :field => field,
      :type => error_type,
      :value => value,
      :description => description
    }
  end

  def add_missing(field)
    add_error(field, :missing, nil, nil)
  end

  def convert(field, type)
    converter(type).call(@data[field])
  end

  def converter(type)
    type.respond_to?(:call) ? type : self.class.converters[type]
  end

  def symbolize_keys(data)
    data.inject({}) do |memo, kv|
      memo[kv.first.to_sym] = kv.last
      memo
    end
  end

  def self.set_keys_to_type(keys, type)
    opts = extract_options!(keys)
    keys.each do |key|
      fields[key] = { :type => type, :options => opts }
    end
  end
end
