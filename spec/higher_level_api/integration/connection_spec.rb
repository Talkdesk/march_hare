require "spec_helper"

java_import java.util.concurrent.CountDownLatch
java_import java.util.concurrent.TimeUnit

describe "MarchHare.connect" do

  #
  # Examples
  #

  it "lets you specify requested heartbeat interval" do
    c1 = MarchHare.connect(:requested_heartbeat => 10)
    c1.close
  end

  it "lets you specify connection timeout interval" do
    c1 = MarchHare.connect(:connection_timeout => 3)
    c1.close
  end

  if !ENV["CI"] && ENV["TLS_TESTS"]
    it "supports TLS w/o custom protocol or trust manager" do
      c1 = MarchHare.connect(:tls => true, :port => 5671)
      c1.close
    end
  end

  context "when connection fails due to unknown host" do
    it "raises an exception" do
      lambda {
        MarchHare.connect(:hostname => "a8s878787s8d78sd78.lol")
      }.should raise_error(MarchHare::ConnectionRefused)
    end
  end

  context "when connection fails due to RabbitMQ node not running" do
    it "raises an exception" do
      lambda {
        MarchHare.connect(:hostname => "rubymarchhare.info")
      }.should raise_error(MarchHare::ConnectionRefused)
    end
  end

  context "when connection fails due to invalid credentials" do
    it "raises an exception" do
      lambda {
        MarchHare.connect(:username => "this$username%does*not&exist")
      }.should raise_error(MarchHare::PossibleAuthenticationFailureError)
    end
  end

  it "lets you specify executor (thread pool) factory" do
    calls = 0
    factory = double(:executor_factory)
    factory.stub(:call) do
      calls += 1
      MarchHare::JavaConcurrent::Executors.new_cached_thread_pool
    end
    c1 = MarchHare.connect(:executor_factory => factory)
    c1.close
    c1.automatically_recover
    c1.close
    calls.should == 2
  end


  it "lets you specify fixed thread pool size" do
    c = MarchHare.connect(:thread_pool_size => 20)
    c.should be_connected
    c.close
    c.should_not be_connected
    c.automatically_recover
    c.should be_connected
    c.close
  end

  it "lets you specify multiple hosts" do
    c = MarchHare.connect(:hosts => ["127.0.0.1"])
    c.should be_connected
    c.close
    c.should_not be_connected
    c.automatically_recover
    c.should be_connected
    c.close
  end

  it "lets you specify thread factory (e.g. for GAE)" do
    class ThreadFactory
      include java.util.concurrent.ThreadFactory

      def newThread(runnable)
        java.lang.Thread.new(runnable)
      end
    end

    c  = MarchHare.connect(:thread_factory => ThreadFactory.new)
    c.should be_connected
    ch = c.create_channel
    c.close
  end

  it "lets you specify exception handler" do
    class ExceptionHandler < com.rabbitmq.client.impl.DefaultExceptionHandler
      include com.rabbitmq.client.ExceptionHandler

      def handleConsumerException(ch, ex, consumer, tag, method_name)
        # different from the default in that it does not print
        # anything. MK.
      end
    end

    c  = MarchHare.connect(:exception_handler => ExceptionHandler.new)
    ch = c.create_channel
    q  = ch.queue("", exclusive: true)
    q.subscribe do |*args|
      raise "oops"
    end

    x  = ch.default_exchange
    x.publish("", :routing_key => q.name)
    sleep 0.5

    c.close
  end
end


describe "MarchHare::Session#start" do
  it "is a no-op added for better compatibility with Bunny and to guard non-idempotent AMQConnection#start" do
    c = MarchHare.connect
    100.times do
      c.start
    end

    c.close
  end
end
