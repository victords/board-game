include MiniGL

class Character < GameObject
  IMAGE_GAPS = {
    cat: Vector.new(0, 0),
    rabbit: Vector.new(0, -14)
  }.freeze

  SPEED = 4

  attr_writer :z_offset
  attr_accessor :tile, :score, :extra_rolls, :extra_dice

  def initialize(board, name)
    super(0, 0, 128, 128, "char_#{name}", IMAGE_GAPS[name], 2, 1)
    @board = board
    @name = name
    @score = 0
    @z_offset = 0
    @extra_rolls = 0
    @extra_dice = 0
    @cooldown = 0
  end

  def update
    animate([0, 1], 15)
    if @target
      move_free(@target, 3)
      @target = nil if @speed.x == 0 && @speed.y == 0
    end
  end

  def start_turn
    options = {
      'Roll die' => proc { @board.set_state :rolling }
    }

    case @name
    when :cat
      @extra_rolls = 1
    when :rabbit
      if @cooldown.zero?
        options['Ability: + 1 die'] = proc do
          @extra_dice = 1
          @cooldown = 3
          @board.set_state :rolling
        end
      else
        @cooldown -= 1
      end
    end

    options
  end

  def set_position(x, y)
    @x = x - @w / 2
    @y = y - @h
  end

  def set_target(x, y)
    @target = Vector.new(x - @w / 2, y - @h)
  end

  def set_cooldown
    case @name
    when :rabbit
      @cooldown = 3
    end
  end

  def moving?
    @speed.x != 0 || @speed.y != 0
  end

  def draw(map)
    super(map, 1, 1, 255, 0xffffff, nil, nil, 9 + @z_offset)
  end
end
