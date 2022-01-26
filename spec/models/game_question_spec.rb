require 'rails_helper'

RSpec.describe GameQuestion, type: :model do

  let(:game_question) do
    create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end

  context 'game status' do
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      expect(game_question.answer_correct?('b')).to be(true)
    end

    it 'correct level & text delegates' do
      expect(game_question.level).to eq(game_question.question.level)
      expect(game_question.text).to eq(game_question.question.text)
    end
  end

  describe '#correct_answer_key' do
    it 'returns correct answer key' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  describe '.help_hash'do
    it 'returns empty hash at the start game' do
      expect(game_question.help_hash).to eq({})
    end

    it 'fills the hash' do
      game_question.help_hash[:audience_help] = 'true'
      expect(game_question.save).to be(true)
      expect(game_question.help_hash).to eq({audience_help: 'true'})
    end
  end

  describe '#add_audience_help' do
    it 'returns empty key before use' do
      expect(game_question.help_hash).not_to include(:audience_help)
    end

      context 'when help of audience is used' do
        before { game_question.add_audience_help }

        it 'include added key after use' do
          expect(game_question.help_hash).to include(:audience_help)
        end

        it 'includes valid answers key' do
          ah = game_question.help_hash[:audience_help]
          expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
        end
    end
  end

  describe '#add_fifty_fifty' do
    it 'returns empty key before use' do
      expect(game_question.help_hash).not_to include(:fifty_fifty)
    end

    context 'when 50/50 help is used' do
      before { game_question.add_fifty_fifty }
      let(:ff) { game_question.help_hash[:fifty_fifty] }

      it 'include added key after use' do
        expect(game_question.help_hash).to include(:fifty_fifty)
      end

      it 'returns two variants' do
        expect(ff.size).to eq(2)
      end

      it 'returns correct answer key' do
        expect(ff).to include(game_question.correct_answer_key)
      end
    end
  end

  describe '#add_friend_call' do
    it 'returns empty key before use' do
      expect(game_question.help_hash).not_to include(:friend_call)
    end

    context 'when call a friend is used' do
      before { game_question.add_friend_call }
      let(:fc) { game_question.help_hash[:friend_call] }

      it 'include added key after use' do
        expect(game_question.help_hash).to include(:friend_call)
      end

      it 'displays correct tip text' do
        expect(fc).to include('считает, что это вариант')
      end

      it 'returns one of keys' do
        expect(fc).to match(/[ABCD]/)
      end
    end
  end
end
