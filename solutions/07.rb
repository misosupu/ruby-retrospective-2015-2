# Defines helper functions to detect if a date meets a periodicity condition
module DateArithmetic
  def detect_periodicity_type(periodicity)
    case periodicity
    when /^.w$/ then return :week
    when /^.m$/ then return :month
    when /^.y$/ then return :year
    when /^.d$/ then return :day
    end
  end

  def check_periodicity(date, agenda, option)
    return false if agenda < date
    case detect_periodicity_type(option)
    when :year then return (date - agenda) % (option[0].to_i * 360) == 0
    when :month then return (date - agenda) % (option[0].to_i * 30) == 0
    when :week then return (date - agenda) % (option[0].to_i * 7) == 0
    when :day then return (date - agenda) % option[0].to_i == 0
    end
  end

  def increment(date)
    new_date = LazyMode::Date.new(date.to_s)
    new_date.date.map! { |element| element.to_i }
    new_date.date[2] += 1
    new_date.date[1] += 1 if new_date.date[2] > 30
    new_date.date[0] += 1 if new_date.date[1] > 12
    sanitize_date new_date
  end

  def sanitize_date(date)
    date.date[2].to_i -= 30 if date.date[2].to_i > 30
    date.date[2].to_i -= 1  if date.date[1].to_i > 12
    date.date.map! { |element| element.to_s }
    date
  end
end

# Defines a lazy 'ToDo list'
module LazyMode
  def self.create_file(file_name, &block)
    file = LazyMode::File.new(file_name)
    file.instance_eval(&block) if block_given?
    file
  end


  class DateHelper
    def self.pad_date_initialize(index, date)
      if index == 0
        pad_date(:year, date.first)
      else
        pad_date(:not_year, date[index])
      end
    end

    def self.pad_date(type, date_element)
      type == :year ? pad_size = 4 : pad_size = 2
      date_element.prepend('0' * (pad_size - date_element.length))
    end
  end
  # Defines a date in the form 'yyyy-mm-dd'
  class Date
    attr_reader :option
    attr_accessor :date

    def initialize(date)
      @date = date.split('-')
      @date.each_with_index do |_, index|
        DateHelper.pad_date_initialize(index, @date)
      end
    end

    def ==(other)
      year == other.year && month == other.month && day == other.day
    end

    def -(other)
      # finds the difference between two dates in days
      (year - other.year) * 360 + (month - other.month) * 30 + day - other.day
    end

    def <(other)
      self - other < 0
    end

    def year
      @date.first.to_i
    end

    def month
      @date[1].to_i
    end

    def day
      @date.last.to_i
    end

    def to_s
      "%04d-%02d-%02d" % [year, month, day]
    end

  end

  # Defines a "ToDo List" note
  class Note
    attr_reader :header, :tags, :schedule, :sub_notes
    attr_accessor :file_name, :date

    def initialize(header, *tags)
      @header = header
      @tags = *tags
      @sub_notes = []
      @status = :topostpone
    end

    private

    def add_sub_note(sub_note)
      @sub_notes << sub_note
    end

    def note(header, *tags, &block)
      note = Note.new(header, *tags)
      note.instance_eval(&block)
      add_sub_note(note)
    end

    def method_missing(name, argument = nil)
      # puts "Inside method_missing, name = #{name}"
      if [:status, :body].include?(name) && !argument.nil?
        instance_variable_set("@#{name}", argument)
      elsif [:status, :body].include?(name) && argument.nil?
      end
      instance_variable_get("@#{name}")
    end

    def scheduled(date)
      if date.count('+') > 0
        @schedule = date.split('+')
        @schedule[0] = Date.new(@schedule.first.strip!)
      else
        @schedule = [Date.new(date), nil]
      end
    end
  end

  # Defines a note container
  class NoteContainer
    attr_reader :notes
    def initialize
      @notes = []
    end

    def add(note)
      @notes << note
    end
  end

  # Defines a logical file, used for note storage
  class File
    include DateArithmetic
    attr_reader :name, :notes

    def initialize(file_name)
      @name = file_name
      @notes = []
    end

    def daily_agenda(date)
      container = LazyMode::NoteContainer.new
      agenda(date).each { |n| container.add n }
      container
    end

    def weekly_agenda(date)
      container = LazyMode::NoteContainer.new
      0.upto(6).each do |_|
        add_to_agenda(container, date)
        date = increment(date)
      end
      container
    end

    def add_to_agenda(container, date)
      agenda(date).each { |n| container.add n }
    end

    def agenda(date)
      agenda_notes = []
      @notes.each do |note|
        agenda_helper(date, note, agenda_notes)
      end
      agenda_notes
    end

    def agenda_helper(date, note, agenda_notes)
      if (note.schedule.last.nil? && (date == note.schedule.first)) ||\
         (!note.schedule.last.nil? && \
         check_periodicity(note.schedule.first, date, note.schedule.last))
        note.date = date
        agenda_notes << note
      end
    end

    private

    def add_note(note)
      @notes << note
      return if note.sub_notes.length == 0
      note.sub_notes.each { |sub_note| @notes << sub_note } # add recursive note
    end

    def note(header, *tags, &block)
      note = Note.new(header, *tags)
      note.instance_eval(&block)
      note.file_name = @name
      add_note(note)
    end
  end
end
