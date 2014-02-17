#!/usr/bin/env ruby
# -*- encoding: UTF-8 -*-
#
#  general logger
#
require 'monitor'

class BasicLog
  # log-level constant
  FATAL, ERROR, WARN, INFO, DEBUG = 1, 2, 3, 4, 5

  attr_accessor :level

  def initialize(logdev, shift_age=0, shift_size=1048576)
    @level = DEBUG
    #case log_file
    #when String
    #  @log = open(log_file, "a+")
    #  @log.sync = true
    #  @opened = true
    #when NilClass
    #  @log = $stderr
    #else
    #  @log = log_file  # requires "<<". (see BasicLog#log)
    #end
    @log = nil
    if logdev
      @log = LogDevice.new(logdev, 
                :shift_age => shift_age,
                :shift_size => shift_size)
    end
  end

  #def close
  #  @log.close if @opened
  #  @log = nil
  #end
  def close
    @log.close if @log
  end

  def log(level, data)
    if @log && level <= @level
      data += "\n" if /\n\Z/ !~ data
      @log.write(data)
    end
  end

  def <<(obj)
    log(INFO, obj.to_s)
  end

  def fatal(msg) log(FATAL, "!FATAL! " << format(msg)); end
  def error(msg) log(ERROR, "!ERROR! " << format(msg)); end
  def warn(msg)  log(WARN,  "!WARN!  " << format(msg)); end
  def info(msg)  log(INFO,  "[INFO]  " << format(msg)); end
  def debug(msg) log(DEBUG, "[DEBUG] " << format(msg)); end

  def fatal?; @level >= FATAL; end
  def error?; @level >= ERROR; end
  def warn?;  @level >= WARN; end
  def info?;  @level >= INFO; end
  def debug?; @level >= DEBUG; end

  private

  def format(arg)
    str = if arg.is_a?(Exception)
      "#{arg.class}: #{arg.message}\n\t" <<
      arg.backtrace.join("\n\t") << "\n"
    elsif arg.respond_to?(:to_str)
      arg.to_str
    else
      arg.inspect
    end
  end

  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = $1
      line = $2.to_i
      method = $3
      [file, line, method]
    end
  end

  # Device used for logging messages.
  class LogDevice
    attr_reader :dev
    attr_reader :filename

    class LogDeviceMutex
      include MonitorMixin
    end

    def initialize(log = nil, opt = {})
      @dev = @filename = @shift_age = @shift_size = nil
      @mutex = LogDeviceMutex.new
      if log.respond_to?(:write) and log.respond_to?(:close)
        @dev = log
      else
        @dev = open_logfile(log)
        @dev.sync = true
        @filename = log
        @shift_age = opt[:shift_age] || 7
        @shift_size = opt[:shift_size] || 1048576
      end
    end

    def write(message)
      begin
        @mutex.synchronize do
          if @shift_age and @dev.respond_to?(:stat)
            begin
              check_shift_log
            rescue
              warn("log shifting failed. #{$!}")
            end
          end
          begin
            @dev.write(message)
          rescue
            warn("log writing failed. #{$!}")
          end
        end
      rescue Exception => ignored
        warn("log writing failed. #{ignored}")
      end
    end

    def close
      begin
        @mutex.synchronize do
          @dev.close rescue nil
        end
      rescue Exception
        @dev.close rescue nil
      end
    end

  private

    def open_logfile(filename)
      if (FileTest.exist?(filename))
        open(filename, (File::WRONLY | File::APPEND))
      else
        create_logfile(filename)
      end
    end

    def create_logfile(filename)
      logdev = open(filename, (File::WRONLY | File::APPEND | File::CREAT))
      logdev.sync = true
      add_log_header(logdev)
      logdev
    end

    def add_log_header(file)
      file.write(
        "# Logfile created on %s by %s\n" % [Time.now.to_s, __FILE__]
      )
    end

    SiD = 24 * 60 * 60

    def check_shift_log
      if @shift_age.is_a?(Integer)
        # Note: always returns false if '0'.
        if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)
          shift_log_age
        end
      else
        now = Time.now
        period_end = previous_period_end(now)
        if @dev.stat.mtime <= period_end
          shift_log_period(period_end)
        end
      end
    end

    def shift_log_age
      (@shift_age-3).downto(0) do |i|
        if FileTest.exist?("#{@filename}.#{i}")
          File.rename("#{@filename}.#{i}", "#{@filename}.#{i+1}")
        end
      end
      @dev.close rescue nil
      File.rename("#{@filename}", "#{@filename}.0")
      @dev = create_logfile(@filename)
      return true
    end

    def shift_log_period(period_end)
      postfix = period_end.strftime("%Y%m%d") # YYYYMMDD
      age_file = "#{@filename}.#{postfix}"
      if FileTest.exist?(age_file)
        # try to avoid filename crash caused by Timestamp change.
        idx = 0
        # .99 can be overridden; avoid too much file search with 'loop do'
        while idx < 100
          idx += 1
          age_file = "#{@filename}.#{postfix}.#{idx}"
          break unless FileTest.exist?(age_file)
        end
      end
      @dev.close rescue nil
      File.rename("#{@filename}", age_file)
      @dev = create_logfile(@filename)
      return true
    end

    def previous_period_end(now)
      case @shift_age
      when /^daily$/
        eod(now - 1 * SiD)
      when /^weekly$/
        eod(now - ((now.wday + 1) * SiD))
      when /^monthly$/
        eod(now - now.mday * SiD)
      when /^test$/
        eod(now - 1 * SiD)
      else
        now
      end
    end

    def eod(t)
      Time.mktime(t.year, t.month, t.mday, 23, 59, 59)
    end
  end
end

class Log < BasicLog
  attr_accessor :header_format,:backtrace

  def initialize(logdev, shift_age=0, shift_size=1048576)
    super(logdev, shift_age, shift_size)
    @header_format = "[%Y-%m-%d %H:%M:%S]"
  end

  def log(level, data)
    tmp = Time.now.strftime(@header_format)
    tmp << " " << parse_caller(caller[1])
    tmp << " " << data
    super(level, tmp)
  end

  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = File::basename($1)
      line = $2.to_i
      #method = $3
      "#{file}:#{line}"
    end
  end
end


if __FILE__ == $0
  # test
  logger = Log.new('/tmp/log_test.log',5,5000)
  10000.times do |cnt|
    logger.debug cnt
  end
end


