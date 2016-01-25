module TurtleGraphics
  class Turtle
    DIRECTIONS = [:left, :up, :right, :down]

    def initialize(rows, columns, default = 0)
      @x_coordinate = 0
      @y_coordinate = 0
      @rows = rows
      @columns = columns
      @orientation = :right
      @matrix ||= []
      @rows.times { @matrix << Array.new(@columns, default) }
      update_canvas(@x_coordinate, @y_coordinate)
    end

    def turn_right
      @orientation = DIRECTIONS[(DIRECTIONS.find_index(@orientation) + 1) % 4]
    end

    def turn_left
      @orientation = DIRECTIONS[(DIRECTIONS.find_index(@orientation) - 1) % 4]
    end

    def spawn_at(row, column)
      @matrix[0][0] = 0
      @x_coordinate = row
      @y_coordinate = column
      update_canvas(@x_coordinate, @y_coordinate)
    end

    def draw(canvas = nil, &block)
      instance_eval &block if block_given?
      if canvas.instance_of?(Canvas::ASCII) || canvas.instance_of?(Canvas::HTML)
        canvas.draw(@matrix)
      else
        @matrix
      end
    end

    def look(orientation)
      @orientation = orientation
    end

    def move
      case @orientation
      when :left then @y_coordinate -= 1
      when :right then @y_coordinate += 1
      when :down then @x_coordinate += 1
      when :up then @x_coordinate -= 1
      end
      update_canvas(@x_coordinate, @y_coordinate)
    end

    private

    def update_canvas(row, column)
      # check if turtle is out of bounds
      if (row >= 0 && row < @rows && column >= 0 && column < @columns) == false
        case @orientation
        when :up then @x_coordinate = @rows - 1
        when :down then @x_coordinate = 0
        when :left then @y_coordinate = @columns - 1
        when :right then @y_coordinate = 0
        end
        @matrix[@x_coordinate][@y_coordinate] += 1
      else
        @matrix[row][column] += 1
      end
    end
  end

  module Canvas
    class ASCII
      attr_accessor :hops, :intensity_ranges

      def initialize(drawing_symbols)
        @max_hops = 0
        @intensity_symbols = drawing_symbols
      end

      def draw(canvas_data)
        raw_data = canvas_data.flatten
        additional_initialize(raw_data)
        picture = raw_data.map { |pixel| calculate_intensity(pixel) }
        picture.join.scan(/.{#{canvas_data[0].length}}|.+/).join("\n")
      end

      private

      def calculate_intensity(pixel_intensity)
        return @intensity_symbols[0] if pixel_intensity == 0
        pixel_intensity /= @max_hops.to_f
        index = @intensity_ranges.find_index { |item| pixel_intensity <= item }
        @intensity_symbols[index]
      end

      def additional_initialize(data)
        @max_hops = data.max
        @intensity_ranges = [0]
        step = 1 / (@intensity_symbols.length.to_f - 1)
        @intensity_symbols[1..-1].each_with_index do |_, index|
          @intensity_ranges << step * (index + 1)
        end
      end
    end

    class HTML
      def initialize(pixel_size)
        @picture = '<!DOCTYPE html><html><head><title>Turtle graphics </title>'
        @picture += pixel_size(pixel_size) + '</head><body><table>'
      end

      def draw(canvas_data)
        @max_hops = canvas_data.flatten.max
        canvas_data.each do |row|
          @picture += '<tr>'
          row.map do |pixel|
            @picture += pixel_style(format('%.2f', calculate_intensity(pixel)))
          end
          @picture += '</tr>'
        end
        @picture += '</table></body></html>'
      end

      private

      def pixel_size(size)
        "<style>table {border-spacing: 0;}tr {padding: 0;}td {width: #{size}" \
        "px; height: #{size}px;background-color: black;padding: 0;}</style>"
      end

      def pixel_style(pixel_size)
        "<td style=\"opacity: #{pixel_size}\"></td>"
      end

      def calculate_intensity(pixel)
        pixel / @max_hops.to_f
      end
    end
  end
end
