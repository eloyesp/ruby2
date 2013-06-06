# Ruby 2.0 #

> Un intento de presentación con mucho código.

¿Ruby recién está en la versión 2?

Si.

# ¿Qué tiene de nuevo? #

Bueno, hay distintas posturas, los que miran primero cuales son las
cosas incompatibles y los que miran la nueva funcionalidad.

Yo, miro la nueva funcionalidad.

Estoy ansioso de hacer codigo **incompatible** con 1.9.

# ¿Cómo qué? #

Bueno, acá hago una pausa y intento explicar que tiene de bueno ruby.

Ruby es:

- Expresivo
- Claro
- Conciso
- Autodocumentado

cierro paréntesis y vuelvo a...

# ¿Qué hay de nuevo? #

# Keyword arguments #

Bueno, la idea es que el típico hash de opciones que uno mira cuando
escribe el método y todo de una forma clara.

Veamos como funcionaba esto en ruby 1.9:

~~~ ruby
# File actionpack/lib/abstract_controller/callbacks.rb, line 69

def _insert_callbacks(callbacks, block)
  options = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
  _normalize_callback_options(options)
  callbacks.push(block) if block
  callbacks.each do |callback|
    yield callback, options
  end
end

# File actionpack/lib/abstract_controller/callbacks.rb, line 33

def _normalize_callback_options(options)
  if only = options[:only]
    only = Array(only).map {|o| "action_name == '#{o}'"}.join(" || ")
    options[:per_key] = {:if => only}
  end
  if except = options[:except]
    except = Array(except).map {|e| "action_name == '#{e}'"}.join(" || ")
    options[:per_key] = {:unless => except}
  end
end
~~~

Bueno... ¿es feo no? pero es rails y el uso es más bien simple. Es un
before filter.

# Cómo queda en ruby 2.0? #

~~~ ruby
def _insert_callbacks(callbacks, only: [], except: [], block)
  # options = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
  _normalize_callback_options(only: only, except: except)
  callbacks.push(block) if block
  callbacks.each do |callback|
    yield callback, options
  end
~~~

Bueno... ese es un pequeño refactory, se puede hacer mejor... pero eso
nos va a servir por ahora.

# ¿Y está bueno? #

La ventaja es que ahora nos sacamos de encima una linea (que ahora está
comentada) y ganamos además, un error si escribimos mal el before
filter.

~~~ ruby
before_filter :some_method, onli: [:create]
# => ArgumentError!
~~~

Y no solo eso, ahora el método se entiende más y las opciones ahora casi
no es necesario documentarlas.

O sea, que es más:

- Expresivo
- Claro
- Conciso
- Autodocumentado

# Module prepend #

Bueno, este es complicado de ver al principio, pero supongamos que
queremos hacer un módulo para agregar validaciones a un modelo. Mmm...
esperá, eso ya lo hace rails... como lo hace?

# Validaciones en rails #

~~~ ruby
# File activemodel/lib/active_model/validations.rb, line 132

def validate(*args, &block)
  options = args.extract_options!
  if options.key?(:on)
    options = options.dup
    options[:if] = Array.wrap(options[:if])
    options[:if].unshift("validation_context == :#{options[:on]}")
  end
  args << options
  set_callback(:validate, *args, &block)
end
~~~

# Pero hay un callback #

Bueno, está bueno, agrega un callback. Así antes de salvar, tenémos que
correr las validaciones y si pasan, entonces lo guardo.
Esto funciona, obviamente porque ActiveRecord *"sabe"* que debe llamar a
este callback. O sea, que si yo hago un nuevo active model y quiero
agregarle validaciones, tengo que acordarme de llamarlas.

~~~ ruby
# File activerecord/lib/active_record/callbacks.rb, line 267
def create #:nodoc:
  run_callbacks(:create) { super }
end
~~~

# En ruby 2 #

Eso no está bueno, pero suele no haber forma de evitarlo. Pero ahora a
mi se me ocurre que podríamos usar module prepend. Cómo?

~~~ ruby
module Validations

  def create
    super if valid?
  end

end

class MyModel
  prepend Validations

  def create
    # un metodo que no se 'acuerda' de llamar a super
  end

end
~~~

Y voila, tenemos validaciones.

# Y ganamos #

Obviamente, esto no hace que nuestro codigo sea totalmente desacoplado
(no solo porque eso es imposible), pero de pronto ha ganado en:

- Expresivo
- Claro
- Conciso
- Autodocumentado (*)

(*) no estoy muy seguro de que esto sea tan así, ya que puede ser
bastante inentendible dónde están las validaciones para quien lea el
código.

# Las otras pequeñas cosas #

- `__dir__`
- `%i`
- `to_h`

# `__dir__` #

![busqueda](http://img703.imageshack.us/img703/9692/selection010k.png "Basta de __FILE__")

Bueno, por se puede escribir `__dir__` para eso...

~~~ ruby
$: << File.expand_path(File.join(__dir__, '..', 'lib'))
~~~

> Por si no se nota, hay un '..' menos, que siempre confunde mucho, ya
> que el primero es para bajar desde `hackerup/test/helper.rb` a
> `hackerup/test`

# %i #

Completando el set de %q, %r... %i

~~~ ruby
%i[ uno dos tres ] #=> [:uno, :dos, :tres]
~~~

A mi en realidad, esto me resultan muy comodos, pero son algo confusos a 
la hora de empezar a usar ruby.

# to_h #

Para completar to_a, to_s, to_sym... faltaba alguien. No anda re-bien,
pero está ahí y almenos plantea un standar.

A mi me permitió conocer a los Struct, que después me cayeron re-bien.


~~~ ruby
Persona = Struct.new(:nombre)  #=> Persona
carlos = Persona.new('carlos') #=> #<struct Persona nombre="carlos">
carlos.to_h                    #=> {:nombre=>"carlos"}
~~~

# Refinements #

Bueno, active support está bueno, lo que hace es agregar un par de cosas
muy útiles en las core classes. O sea, hace monkey patching.

El problema es que el monkey patching puede ser inesperado, así que no
se pone extremadamente violento.

~~~ ruby
require 'active_support'
"".empty?     #=> true
"  ".empty?   #=> false
"".nil?       #=> false
~~~

# ¿Esta claro que es un poquito cagón no? #

Pero tiene un sentido, si se hace de manera muy violenta te puede morder
cuando no lo esperás. La solución a esto es hacer el monkey patching
controlable.

# y podemos usar refinements #

~~~ ruby
module ExtremeMonkeyPatching
  refine String do
    def nil?
      self =~ /^\s*$/
    end
  end
end

using ExtremeMonkeyPatching

"  ".nil? #=> true

# some other file

"  ".nil? #=> false
~~~

# Muchas Gracias #
