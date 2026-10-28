module Carrier
  Timeout = Class.new(StandardError)
  Rejected = Class.new(StandardError)

  Label = Data.define(:tracking_number, :label_url)

  class << self
    attr_writer :client

    def client
      @client ||= FakeClient.new
    end
  end

  # Stands in for a real carrier API, including its bad days.
  #
  # Like real carrier APIs, it accepts a client reference and returns the same
  # label for the same reference. That is what makes retrying after a timeout safe:
  # sometimes the label *was* created and only the response got lost.
  class FakeClient
    def initialize(failure_rate: ENV.fetch("FAKE_CARRIER_FAILURE_RATE", "0.4").to_f, random: Random.new)
      @failure_rate = failure_rate
      @random = random
      @labels = Concurrent::Map.new
    end

    def create_label(reference:, carrier:)
      roll = @random.rand
      raise Timeout, "#{carrier} did not answer within 5s" if roll < @failure_rate / 2

      label = @labels.compute_if_absent(reference) do
        number = "#{carrier.upcase.delete('_')[0, 3]}#{@random.rand(10**9).to_s.rjust(9, '0')}"
        Label.new(tracking_number: number, label_url: "https://labels.example/#{number}.pdf")
      end
      raise Timeout, "#{carrier} created the label but the response was lost" if roll < @failure_rate

      label
    end

    def labels_created = @labels.size
  end
end
