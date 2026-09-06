# Line-oriented output stays readable in terminals and redirected log files.
class TaskProgress
  def initialize(output: $stdout, interval: 5)
    @output, @interval = output, interval
    @started = monotonic
    @last_update = -Float::INFINITY
  end

  def call(message, force: true)
    now = monotonic
    return if !force && now - @last_update < @interval
    elapsed = (now - @started).to_i
    @output.puts("[#{Time.current.strftime('%H:%M:%S')} +#{elapsed / 60}m#{elapsed % 60}s] #{message}")
    @output.flush
    @last_update = now
  end

  private

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
