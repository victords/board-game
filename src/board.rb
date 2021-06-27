require 'minigl'

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
        if j == 0
          p = line.split(',')
          @width = p[0].to_i
          @height = p[1].to_i
          @tiles = Array.new(@width) do
            Array.new(@height)
          end
        else
          (0...line.size).each do |i|
            @tiles[i][j - 1] = line[i] == '.' ? -1 : 0
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
        @floor[tile].draw(i * @floor_w + @margin_x, j * @floor_h + @margin_y, 0) if tile >= 0
      end
    end
  end
end
