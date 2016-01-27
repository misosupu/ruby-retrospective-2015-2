require 'ostruct'

module Validate
  ARITHMETIC_FUNCTIONS = { ADD: [2, Float::INFINITY, :+],
                           MULTIPLY: [2, Float::INFINITY, :*],
                           SUBTRACT: [2, 2, :-],
                           DIVIDE: [2, 2, :/],
                           MOD: [2, 2, :%] }

  def validate_index(index)
    if (index =~ /^[A-Z]+\d+$/).nil?
      raise self.class::Error.new("Invalid cell index #{index}")
    else
      return true
    end
  end

  def validate_function_exists(function, valid_functions)
    # check if function name exists
    unless valid_functions.include?(function.name)
      raise self.class::Error.new("Unknown function '#{function.name}'")
    end
  end

  def validate_function(function)
    validate_function_exists(function, ARITHMETIC_FUNCTIONS.keys)
    # check if number of arguments passed is correct
    validate_function_parameters(function)
  end

  def validate_function_parameters(function)
    error_class = self.class::Error
    if ARITHMETIC_FUNCTIONS[function.name][1] != Float::INFINITY &&
       function.parameters.length != ARITHMETIC_FUNCTIONS[function.name][0]
      raise error_class.new(error_class.argument_mismatch_strict(function))
    elsif function.parameters.length < ARITHMETIC_FUNCTIONS[function.name][0]
      raise error_class.new(error_class.argument_mismatch_loose(function))
    end
  end
end

module Parser
  ALPHABET_SIZE   = 'Z'.ord - 'A'.ord + 1
  ALPHABET_OFFSET = 'A'.ord - 1

  def parse_number(number)
    number == number.floor ? number.to_i.to_s : '%.2f' % number
  end

  def parse_sheet(sheet)
    sheet = sheet.split("\n")
    sheet = sheet.reject { |row| row =~ /^\s*$/ }.map(&:strip)
    sheet.each do |row|
      row = row.split(/\t|(?:\ {2,})/)
      @sheet << row
    end
    @sheet
  end

  def letter_index_to_number(letter_index)
    letter_index.chars.reverse.map.with_index do |char, position|
      (char.ord - ALPHABET_OFFSET) * ALPHABET_SIZE**position
    end.reduce(:+)
  end

  def convert_index(cell_index)
    indexes = cell_index.scan(/[A-Z]+|\d+/)
    indexes[0] = letter_index_to_number(indexes[0]) - 1
    indexes[1] = indexes.last.to_i - 1
    indexes.reverse
  end

  def evaluate_function(function)
    match = /^=([A-Z]+)\((.+)\)$/.match(function)
    # check if function is syntactically correct
    raise self.class::Error, ("Invalid expression '#{function}'") if match.nil?
    parameters = match[2].split(',').map(&:strip)
    function = OpenStruct.new(name: match[1].to_sym, parameters: parameters)
    validate_function(function)
    call_function(function)
  end

  def parse_row(row)
    row.map do |cell|
      cell.count('=') != 0 ? evaluate_expression(cell) : cell
    end.join("\t")
  end
end

class Spreadsheet
  include Validate, Parser

  def initialize(sheet = '')
      @sheet = []
      parse_sheet(sheet)
  end

  def empty?
    @sheet.empty?
  end

  def cell_at(cell_index)
    validate_index(cell_index)
    cell_at = cell_index
    cell_index = convert_index(cell_index)
    if cell_index.first >= @sheet.size || cell_index.last >= @sheet[0].size
      raise Error.new("Cell '#{cell_at}' does not exist")
    else
      return @sheet[cell_index.first][cell_index.last]
    end
  end

  def [](cell_index)
    evaluate_cell(cell_index)
  end

  def to_s
    @sheet.map do |row|
      parse_row(row)
    end.join("\n")
  end

  private

  def call_function(function)
    parse_number(function.parameters.map do |cell|
      evaluate_expression('=' + cell).to_f
    end.reduce(Validate::ARITHMETIC_FUNCTIONS[function.name][2]))
  end

  def evaluate_cell(cell_index)
    cell = cell_at(cell_index)
    return evaluate_expression(cell) if cell.count("=") != 0
    cell
  end

  def evaluate_expression(expression)
    case expression
    when /^=[\d\.]+$/ then return expression[1..-1]
    when /^=[A-Z]+\d+$/ then return evaluate_cell(expression[1..-1])
    else return evaluate_function(expression)
    end
  end

  class Error < Exception
    def initialize(message)
      @message = message
    end

    def to_s
      @message
    end

    def self.argument_mismatch_strict(function)
      "Wrong number of arguments for '#{function.name}': " \
      "expected #{Validate::ARITHMETIC_FUNCTIONS[function.name][0]}, " \
      "got #{function.parameters.length}"
    end

    def self.argument_mismatch_loose(function)
      "Wrong number of arguments for '#{function.name}': expected at least " \
      "#{Validate::ARITHMETIC_FUNCTIONS[function.name][0]}, " \
      "got #{function.parameters.length}"
    end
  end
end