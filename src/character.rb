include MiniGL

class Character < GameObject
  IMAGE_GAPS = {
    rabbit: Vector.new(0, -14),
  }.freeze

  SPEED = 8

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
    @stun = 0
  end

  def update
    animate([0, 1], 15)
    if @target
      move_free(@target, SPEED)
      @target = nil if @speed.x == 0 && @speed.y == 0
    end
  end

  def start_turn
    if @stun.positive?
      @stun -= 1
      return
    end

    @current = true

    @cooldown -= 1 if @cooldown.positive?
    return unless @cooldown.zero?

    case @name
    when :cat
      @extra_rolls = 1
    when :rabbit
      @board.add_option('Ability: + 1 die') do
        @extra_dice = 1
        set_cooldown
        @board.set_state :rolling
      end
    when :duck
      @tile.unset_prop(:blocked)
    when :frog
      @ignore_block = true
    end
  end

  def set_position(x, y)
    @x = x - @w / 2
    @y = y - @h
  end

  def set_target(x, y)
    @target = Vector.new(x - @w / 2, y - @h)
  end

  def set_cooldown
    @cooldown = 3
  end

  def stun(turns = 1)
    @stun = turns
  end

  def moving?
    @speed.x != 0 || @speed.y != 0
  end

  def stunned?
    @stun.positive?
  end

  def ignore_block?
    @ignore_block
  end

  def feet
    Vector.new(@x + @w / 2, @y + @h)
  end

  def after_move
    return unless @cooldown.zero?

    case @name
    when :duck
      @board.add_option('Block path', true) do
        @tile.set_prop(:blocked)
        set_cooldown
      end
    when :panda
      @board.set_targets(@tile, 2, 'Stun') do |t|
        t.stun
        set_cooldown
      end
    end
  end

  def end_turn
    @current = false
  end

  def draw(map)
    alpha = @current ? 255 : 204
    super(map, 1, 1, alpha, 0xffffff, nil, nil, 9 + @z_offset)
  end
end
