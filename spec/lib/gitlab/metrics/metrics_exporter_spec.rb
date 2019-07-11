require 'spec_helper'

describe Gitlab::Metrics::MetricsExporter do
  let(:exporter) { described_class.new }
  let(:server) { double('server') }
  let(:log_filename) { File.join(Rails.root, 'log', 'sidekiq_exporter.log') }
  let(:settings) { double('settings') }

  before do
    allow(::WEBrick::HTTPServer).to receive(:new).and_return(server)
    allow(server).to receive(:mount)
    allow(server).to receive(:start)
    allow(server).to receive(:shutdown)
    allow_any_instance_of(described_class).to receive(:log_filename).and_return(log_filename)
    allow_any_instance_of(described_class).to receive(:settings).and_return(settings)
  end

  describe 'when exporter is enabled' do
    before do
      allow(settings).to receive(:enabled).and_return(true)
      allow(settings).to receive(:port).and_return(3707)
      allow(settings).to receive(:address).and_return('localhost')
    end

    describe 'when exporter is stopped' do
      describe '#start' do
        it 'starts the exporter' do
          expect { exporter.start.join }.to change { exporter.thread? }.from(false).to(true)

          expect(server).to have_received(:start)
        end

        describe 'with custom settings' do
          let(:port) { 99999 }
          let(:address) { 'sidekiq_exporter_address' }

          before do
            allow(settings).to receive(:port).and_return(port)
            allow(settings).to receive(:address).and_return(address)
          end

          it 'starts server with port and address from settings' do
            exporter.start.join

            expect(::WEBrick::HTTPServer).to have_received(:new).with(
              Port: port,
              BindAddress: address,
              Logger: anything,
              AccessLog: anything
            )
          end
        end
      end

      describe '#stop' do
        it "doesn't shutdown stopped server" do
          expect { exporter.stop }.not_to change { exporter.thread? }

          expect(server).not_to have_received(:shutdown)
        end
      end
    end

    describe 'when exporter is running' do
      before do
        exporter.start.join
      end

      describe '#start' do
        it "doesn't start running server" do
          expect { exporter.start.join }.not_to change { exporter.thread? }

          expect(server).to have_received(:start).once
        end
      end

      describe '#stop' do
        it 'shutdowns server' do
          expect { exporter.stop }.to change { exporter.thread? }.from(true).to(false)

          expect(server).to have_received(:shutdown)
        end
      end
    end
  end

  describe 'when exporter is disabled' do
    before do
      allow(settings).to receive(:enabled).and_return(false)
    end

    describe '#start' do
      it "doesn't start" do
        expect(exporter.start).to be_nil
        expect { exporter.start }.not_to change { exporter.thread? }

        expect(server).not_to have_received(:start)
      end
    end

    describe '#stop' do
      it "doesn't shutdown" do
        expect { exporter.stop }.not_to change { exporter.thread? }

        expect(server).not_to have_received(:shutdown)
      end
    end
  end
end
