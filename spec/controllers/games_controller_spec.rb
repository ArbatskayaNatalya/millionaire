require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

RSpec.describe GamesController, type: :controller do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }


  context 'when user is not signed in' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id
      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path) # devise redirect for anon
      expect(flash[:alert]).to be
    end

    it 'kick from #create' do
      post :create
      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money, id: game_w_questions.id
      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #help' do
      put :help, id: game_w_questions.id
      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end

  context 'when user is signed in' do
    before { sign_in user }

    it 'creates game' do
      generate_questions(60)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      expect(game.finished?).to be(false)
      expect(game.user).to eq(user)

      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be(false)
      expect(game.user).to eq(user)

      expect(response.status).to eq(200)
      expect(response).to render_template('show') # render viev show
    end

    context 'when user try to open someone else`s game' do
      it '#show alien game' do
        alien_game = FactoryBot.create(:game_with_questions)

        get :show, id: alien_game.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when user try to take money' do
      it 'takes money' do
        # up current level question
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money, id: game_w_questions.id
        game = assigns(:game)

        expect(game.finished?).to be(true)
        expect(game.prize).to eq(200)

        user.reload
        expect(user.balance).to eq(200)

        expect(response).to redirect_to(user_path(user))
        expect(flash[:warning]).to be
      end
    end

    context 'when user tries to create a second game when the first one is not finished' do
      it 'try to create second game' do
        expect(game_w_questions.finished?).to be_falsey

        expect { post :create }.to change(Game, :count).by(0)

        game = assigns(:game)
        expect(game).to be_nil

        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end
  end

  describe '#answer' do
    context 'when user is not signed in' do
      it 'kick from #answer' do
        put :answer, id: game_w_questions.id, letter: 'a'
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when user is signed in' do
      before { sign_in user }
      let(:game) { assigns(:game) }

      context 'when the answer is correct' do
        before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }

        it 'returns correct game status' do
          expect(game.finished?).to be(false)
          expect(game.status).to eq(:in_progress)
          expect(game.current_level).to be(1)
        end

        it 'redirect to right routes' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'returns empty flash' do
          expect(flash.empty?).to be(true)
        end
      end

      context 'when the answer is not correct' do
        before { put :answer, id: game_w_questions.id, letter: 'a' }

        it 'returns finished game status' do
          expect(game.finished?).to be(true)
          expect(game.status).to eq(:fail)
        end

        it 'redirect to right routes' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'has alert flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end
end
