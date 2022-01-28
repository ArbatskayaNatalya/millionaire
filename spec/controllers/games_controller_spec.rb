require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

RSpec.describe GamesController, type: :controller do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe '#create' do
    context 'when user is not signed in' do
      it 'kick from #answer' do
        post :create
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when user is signed in' do
      before do
        sign_in user
        generate_questions(60)
        post :create
      end

      let(:game) { assigns(:game) }

      it 'continues game' do
        expect(game.finished?).to be(false)
        expect(game.user).to eq(user)
      end

      it 'redirect to right routes' do
        expect(response).to redirect_to(game_path(game))
      end

      it 'has notice flash' do
        expect(flash[:notice]).to be
      end
    end

    context 'when user tries to create a second game when the first one is not finished' do
      before { sign_in user }
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

  describe '#show' do
    context 'when user is not signed in' do
      it 'kick from #show' do
        get :show, id: game_w_questions.id
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path) # devise redirect for anon
        expect(flash[:alert]).to be
      end
    end

    context 'when user is signed in' do
      before do
        sign_in user
        get :show, id: game_w_questions.id
      end

      let(:game) { assigns(:game) }

      it '#show game' do
        expect(game.finished?).to be(false)
        expect(game.user).to eq(user)

        expect(response.status).to eq(200)
        expect(response).to render_template('show') # render viev show
      end
    end

    context 'when user try to open someone else`s game' do
      before { sign_in user }
      it '#show alien game' do
        alien_game = FactoryBot.create(:game_with_questions)

        get :show, id: alien_game.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be
      end
    end
  end

  describe '#help' do
    context 'when user is not signed in' do
      it 'kick from #help' do
        put :help, id: game_w_questions.id
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when try audience help' do
      before { sign_in user }
      it 'returns empty key before use' do
        expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        expect(game_w_questions.audience_help_used).to be(false)
      end

      context 'when help of audience is used' do
        before { put :help, id: game_w_questions.id, help_type: :audience_help }
        let(:game) { assigns(:game) }

        it 'continues game' do
          expect(game.finished?).to be(false)
          expect(game.status).to eq(:in_progress)
        end

        it 'include added key after use' do
          expect(game.audience_help_used).to be(true)
          expect(game.current_game_question.help_hash[:audience_help]).to be
        end
        it 'returns all valid answers key ' do
          expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        end
        it 'redirects to game_path' do
          expect(response).to redirect_to(game_path(game))
        end
      end
    end

    context 'when try 50/50 help' do
      before { sign_in user }
      it 'returns empty key before use' do
        expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
        expect(game_w_questions.fifty_fifty_used).to be(false)
      end

      context 'when 50/50 help is used' do
        before { put :help, id: game_w_questions.id, help_type: :fifty_fifty }
        let(:game) { assigns(:game) }

        it 'continues game' do
          expect(game.finished?).to be(false)
          expect(game.status).to eq(:in_progress)
        end

        it 'includes added key after use' do
          expect(game.fifty_fifty_used).to be(true)
          expect(game.current_game_question.help_hash[:fifty_fifty]).to be
        end

        it 'returns correct answer key' do
          expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
        end

        it 'returns two variants' do
          expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
        end

        it 'redirects to game_path' do
          expect(response).to redirect_to(game_path(game))
        end
      end
    end
  end

  describe '#take_money' do
    context 'when user is not signed in' do
      it 'kick from #take_money' do
        put :take_money, id: game_w_questions.id
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end
    end

    context 'when user is signed in' do
      before { sign_in user }
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

        it 'continues game' do
          expect(game.finished?).to be(false)
          expect(game.status).to eq(:in_progress)
          expect(game.current_level).to be(1)
        end

        it 'redirects to right routes' do
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

        it 'redirects to right routes' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'has alert flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end
end
