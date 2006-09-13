require 'sand_table'
require 'thread'

class Sandbox
  private :_eval
  private :finish

  BUILD = "#{VERSION}.#{REV_ID[6..-3]}" #:nodoc:
  PRELUDE = File.expand_path("../sandbox/prelude.rb", __FILE__) #:nodoc:

  #
  # Stands in for an exception raised within the sandbox during evaluation.
  # (See Sandbox#eval.)
  #
  class Exception
  end

  #
  # Raised when the duration of a sandbox operation exceeds a specified
  # timeout.  (See Sandbox#eval.)
  #
  class TimeoutError < Sandbox::Exception
  end

  #
  # call-seq:
  #    sandbox.eval(str, opts={})   => obj
  #
  # Evaluates +str+ as Ruby code inside the sandbox and returns
  # the result.  If an option hash +opts+ is provided, any options
  # specified in it take precedence over options specified when +sandbox+
  # was created.  (See Sandbox.new.)
  #
  # Available options include:
  #
  # [:timeout]  The maximum time in seconds which Sandbox#eval is allowed to
  #             run before it is forcibly terminated.
  # [:safelevel]  The $SAFE level to use during evaluation in the sandbox.
  #
  # If evaluation times out, Sandbox#eval will raise a
  # Sandbox::TimeoutError.  If no timeout is specified, Sandbox#eval will
  # be allowed to run indefinitely.
  #
  def eval(str, opts = {})
    opts = @options.merge(opts)
    if opts[:timeout] or opts[:safelevel]
      th, timed_out = nil, false
      begin
        safelevel = opts[:safelevel]
        th = Thread.start(str) do
          $SAFE = safelevel if safelevel and safelevel > $SAFE
          _eval(str)
        end
        th.join(opts[:timeout])
        if th.alive?
          if th.respond_to? :kill!
            th.kill!
          else
            th.kill
          end
          timed_out = true
        end
      ensure
        finish
      end
      if timed_out
        raise TimeoutError, "Sandbox#eval timed out"
      else
        th.value
      end
    else
      _eval(str)
    end
  end

  #
  # call-seq:
  #    sandbox.load(portname, opts={})   => obj
  #
  # Reads all available data from the given I/O port +portname+ and
  # then evaluates it as a string in +sandbox+.  (See Sandbox#eval.)
  #
  def load(io, opts = {})
    eval(IO.read(io), opts)
  end

end
