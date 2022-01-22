require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe Game, type: :model do
  let(:user) { create(:user) }
  let(:game_w_questions) { create(:game_with_questions, user: user) }

  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      generate_questions(60)

      game = nil

      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(
        change(GameQuestion, :count).by(15).and(
          change(Question, :count).by(0)
        )
      )

      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  context 'game mechanics' do
    it 'answer correct continues game' do
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      expect(game_w_questions.current_level).to eq(level + 1)
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be(false)
    end

    it 'finish game then .take money!' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      game_w_questions.take_money!
      prize = game_w_questions.prize

      expect(prize).to be > 0
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be(true)
      expect(user.balance).to eq prize
    end
  end

  describe '#status' do
    context 'correct status finishing game' do
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'finishes game with status :won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq(:won)
      end

      it 'finishes game with status :fail' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:fail)
      end

      it 'finishes game with status :timeout' do
        game_w_questions.created_at = 1.hour.ago
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:timeout)
      end

      it 'finishes game with status :money' do
        expect(game_w_questions.status).to eq(:money)
      end
    end
  end

  describe '#current_game_question' do
    it 'returns a question owned by the GameQuestion' do
      expect(game_w_questions.current_game_question).to be_a(GameQuestion)
    end

    it 'returns the question with the correct level' do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions.first)
    end
  end

  describe '#previous_level' do
    it 'returns previous level correctly' do
      expect(expect(game_w_questions.previous_level).to eq(game_w_questions.current_level - 1))
    end
  end

  describe '#answer_current_question!' do
    context 'when the answer is correct' do
      let(:question) { game_w_questions.current_game_question }

      it 'returns true if answer is right' do
        expect(game_w_questions.answer_current_question!('d')).to eq(true)
      end

      context 'it is not last question' do
        before { game_w_questions.answer_current_question!(question.correct_answer_key) }

        it 'the game is go on' do
          expect(game_w_questions.status).to eq(:in_progress)
          expect(game_w_questions.finished?).to be(false)
        end

        it 'moves on to the next question' do
          expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions.second)
        end
      end

      context 'it is the last question' do
        before do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max
          game_w_questions.answer_current_question!(question.correct_answer_key)
        end

        it 'finishes the game' do
          expect(game_w_questions.finished?).to be(true)
        end

        it 'finishes the game with won status' do
          expect(game_w_questions.status).to eq(:won)
        end

        it 'assigns the max prize' do
          expect(game_w_questions.prize).to eq(Game::PRIZES.last)
        end
      end
    end

    context 'when answer is not correct' do
      it 'returns false if answer is wrong' do
        expect(game_w_questions.answer_current_question!('a')).to eq(false)
      end

      before { game_w_questions.answer_current_question!('a') }

      it 'finishes the game with fail status' do
        expect(game_w_questions.status).to eq(:fail)
      end

      it 'finishes the game' do
        expect(game_w_questions.finished?).to be(true)
      end
    end

    context 'when time is out' do
      before { game_w_questions.created_at = 36.minutes.ago }

      it 'returns false on any response' do
        expect(game_w_questions.answer_current_question!('d')).to eq(false)
        expect(game_w_questions.status).to eq(:timeout)
      end
    end
  end
end
