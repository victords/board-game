require_relative 'character'

include MiniGL

TILE_SIZE = 128

class Tile
  CHAR_OFFSETS = [
    [[0, 0, 0]],
    [[-32, -32, 0], [32, 32, 1]],
    [[-32, -32, 0], [32, -32, 1], [0, 32, 2]]
  ]

  attr_accessor :floor_type
  
  def initialize(i, j, floor_type)
    @center = Vector.new(i * TILE_SIZE + TILE_SIZE / 2, j * TILE_SIZE + TILE_SIZE / 2)
    @floor_type = floor_type
    @chars = []
  end
  
  def add_char(char, start = false)
    offsets = CHAR_OFFSETS[@chars.size]
    @chars << char
    @chars.each_with_index do |c, i|
      c.send(start ? :set_position : :set_target, @center.x + offsets[i][0], @center.y + offsets[i][1])
      c.z_offset = offsets[i][2]
    end
  end
end

class Board
  def initialize(id)
    @bg = Res.img("board_bg#{id}")
    @floor = Res.imgs("board_floor#{id}", 3, 3)

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
            @tiles[i][j - 2] = Tile.new(i, j - 2,0) if line[i] != '.'
          end
        end
      end
    end

    @map = Map.new(TILE_SIZE, TILE_SIZE, @width, @height, G.window.width, G.window.height, false, false)
    map_size = @map.get_absolute_size
    @map.set_camera((map_size.x - G.window.width) / 2, (map_size.y - G.window.height) / 2)
    @tiles.each_with_index do |col, i|
      col.each_with_index do |tile, j|
        next unless tile

        up = j > 0 && @tiles[i][j - 1]
        rt = i < @tiles.size - 1 && @tiles[i + 1][j]
        dn = j < @tiles[0].size - 1 && @tiles[i][j + 1]
        lf = i > 0 && @tiles[i - 1][j]
        @tiles[i][j].floor_type = if up
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

    # @margin_x = (G.window.width - @tiles.size * TILE_SIZE) / 2
    # @margin_y = (G.window.height - @tiles[0].size * TILE_SIZE) / 2

    @characters = []
  end

  def add_character(name)
    @characters << (char = Character.new(name))
    @tiles[@start_point[0]][@start_point[1]].add_char(char, true)
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
        next unless tile

        x = i * TILE_SIZE - @map.cam.x
        y = j * TILE_SIZE - @map.cam.y
        @floor[tile.floor_type].draw(x + 8, y + 8, 1, 1, 1, 0x66000000)
        @floor[tile.floor_type].draw(x, y, 2)
      end
    end

    @characters.each do |c|
      c.draw(@map)
    end
  end
end
