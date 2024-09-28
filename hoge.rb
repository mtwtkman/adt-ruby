class C
  attr_reader :a, :b
  def initialize(a, b)
    @a = a
    @b = b
  end
end

class P
  attr_reader :value
  def initialize(x)
    @value = x
  end
end

params = C.instance_method(:initialize).parameters
C.define_method(:initialize) do |*params|
  a, b = params
  @a = P.new(a)
  @b = P.new(b)
end

c = C.new(1, 2)
puts c.a
puts c.b
