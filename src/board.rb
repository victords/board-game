require_relative 'character'

include MiniGL

class Board
  def initialize(id)
    @bg = Res.img("board_bg#{id}")
    @floor = Res.imgs("board_floor#{id}", 3, 3)
    @floor_w = @floor[0].width
    @floor_h = @floor[0].height

    File.open("#{Res.prefix}board/#{id}") do |f|
      f.each_line.with_index do |line, j|
        line = line.chomp
        case j
        when 0
          @width, @height = line.split(',').map(&:to_i)
          @tiles = Array.new(@width) do
            Array.new(@height)
          end
        when 1
          @start_point = line.split(',').map(&:to_i)
        else
          (0...line.size).each do |i|
            @tiles[i][j - 2] = line[i] == '.' ? -1 : 0
          end
        end
      end
    end

    @tiles.each_with_index do |col, i|
      col.each_with_index do |tile, j|
        next if tile == -1

        up = j > 0 && @tiles[i][j - 1] >= 0
        rt = i < @tiles.size - 1 && @tiles[i + 1][j] >= 0
        dn = j < @tiles[0].size - 1 && @tiles[i][j + 1] >= 0
        lf = i > 0 && @tiles[i - 1][j] >= 0
        @tiles[i][j] = if up
                         if rt
                           if dn
                             0
                           else
                             7
                           end
                         elsif dn
                           0
                         elsif lf
                           6
                         else
                           3
                         end
                       elsif rt
                         if dn
                           if lf
                             0
                           else
                             8
                           end
                         elsif lf
                           0
                         else
                           4
                         end
                       elsif dn
                         if lf
                           5
                         else
                           1
                         end
                       else
                         2
                       end
      end
    end

    @margin_x = (G.window.width - @tiles.size * @floor_w) / 2
    @margin_y = (G.window.height - @tiles[0].size * @floor_h) / 2

    @characters = []
  end

  def add_character(name)
    @characters << Character.new(name, @start_point[0] * @floor_w + @margin_x, @start_point[1] * @floor_h + @margin_y)
  end

  def update
    @characters.each(&:update)
  end

  def draw
    x = 0
    while x < G.window.width
      y = 0
      while y < G.window.height
        @bg.draw(x, y, 0)
        y += @bg.height
      end
      x += @bg.width
    end

    @tiles.each_with_index do |col, i|
      col.each_with_index do |tile, j|
        next unless tile >= 0

        x = i * @floor_w + @margin_x
        y = j * @floor_h + @margin_y
        @floor[tile].draw(x + 8, y + 8, 1, 1, 1, 0x66000000)
        @floor[tile].draw(x, y, 2)
      end
    end

    @characters.each(&:draw)
  end
end
