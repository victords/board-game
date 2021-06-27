include MiniGL

class Character < Sprite
  def initialize(name, x, y)
    super(x, y, "char_#{name}", 2, 1)
  end

  def update
    animate([0, 1], 15)
  end

  def draw
    super(nil, 1, 1, 255, 0xffffff, nil, nil, 3)
  end
end
