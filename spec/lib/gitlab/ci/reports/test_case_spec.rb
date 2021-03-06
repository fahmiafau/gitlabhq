# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Reports::TestCase do
  describe '#initialize' do
    let(:test_case) { described_class.new(**params)}

    context 'when both classname and name are given' do
      context 'when test case is passed' do
        let(:params) do
          {
            name: 'test-1',
            classname: 'trace',
            file: 'spec/trace_spec.rb',
            execution_time: 1.23,
            status: described_class::STATUS_SUCCESS,
            system_output: nil,
            job: build(:ci_build)
          }
        end

        it 'initializes an instance' do
          expect { test_case }.not_to raise_error

          expect(test_case.name).to eq('test-1')
          expect(test_case.classname).to eq('trace')
          expect(test_case.file).to eq('spec/trace_spec.rb')
          expect(test_case.execution_time).to eq(1.23)
          expect(test_case.status).to eq(described_class::STATUS_SUCCESS)
          expect(test_case.system_output).to be_nil
          expect(test_case.job).to be_present
        end
      end

      context 'when test case is failed' do
        let(:params) do
          {
            name: 'test-1',
            classname: 'trace',
            file: 'spec/trace_spec.rb',
            execution_time: 1.23,
            status: described_class::STATUS_FAILED,
            system_output: "Failure/Error: is_expected.to eq(300) expected: 300 got: -100"
          }
        end

        it 'initializes an instance' do
          expect { test_case }.not_to raise_error

          expect(test_case.name).to eq('test-1')
          expect(test_case.classname).to eq('trace')
          expect(test_case.file).to eq('spec/trace_spec.rb')
          expect(test_case.execution_time).to eq(1.23)
          expect(test_case.status).to eq(described_class::STATUS_FAILED)
          expect(test_case.system_output)
            .to eq('Failure/Error: is_expected.to eq(300) expected: 300 got: -100')
        end
      end
    end

    context 'when classname is missing' do
      let(:params) do
        {
          name: 'test-1',
          file: 'spec/trace_spec.rb',
          execution_time: 1.23,
          status: described_class::STATUS_SUCCESS,
          system_output: nil
        }
      end

      it 'raises an error' do
        expect { test_case }.to raise_error(ArgumentError)
      end
    end

    context 'when name is missing' do
      let(:params) do
        {
          classname: 'trace',
          file: 'spec/trace_spec.rb',
          execution_time: 1.23,
          status: described_class::STATUS_SUCCESS,
          system_output: nil
        }
      end

      it 'raises an error' do
        expect { test_case }.to raise_error(ArgumentError)
      end
    end

    context 'when attachment is present' do
      let(:attachment_test_case) { build(:test_case, :with_attachment) }

      it "initializes the attachment if present" do
        expect(attachment_test_case.attachment).to eq("some/path.png")
      end

      it '#has_attachment?' do
        expect(attachment_test_case.has_attachment?).to be_truthy
      end

      it '#attachment_url' do
        expect(attachment_test_case.attachment_url).to match(/file\/some\/path.png/)
      end
    end

    context 'when attachment is missing' do
      let(:test_case) { build(:test_case) }

      it '#has_attachment?' do
        expect(test_case.has_attachment?).to be_falsy
      end

      it '#attachment_url' do
        expect(test_case.attachment_url).to be_nil
      end
    end
  end
end
