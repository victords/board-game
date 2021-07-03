include MiniGL

class Character < GameObject
  IMAGE_GAPS = {
    'cat' => Vector.new(0, 0),
    'rabbit' => Vector.new(0, -14)
  }.freeze

  SPEED = 4

  attr_writer :z_offset
  attr_accessor :tile

  def initialize(name)
    super(0, 0, 128, 128, "char_#{name}", IMAGE_GAPS[name], 2, 1)
    @z_offset = 0
  end

  def update
    animate([0, 1], 15)
    if @target
      move_free(@target, 3)
      @target = nil if @speed.x == 0 && @speed.y == 0
    end
  end

  def set_position(x, y)
    @x = x - @w / 2
    @y = y - @h
  end

  def set_target(x, y)
    @target = Vector.new(x - @w / 2, y - @h)
  end

  def moving?
    @speed.x != 0 || @speed.y != 0
  end

  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, nil, 4 + @z_offset)
  end
end
