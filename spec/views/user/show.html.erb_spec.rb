require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  context 'when the current user view his page' do
    before(:each) do
      user = assign(:user, FactoryBot.build_stubbed(:user, name: 'User1'))
      allow(view).to receive(:current_user).and_return(user)
      assign(:games, [FactoryBot.build_stubbed(:game)])
      stub_template 'users/_game.html.erb' => 'User game goes here'
      render
    end

    it 'returns user name' do
      expect(rendered).to match 'User1'
    end
    it 'returns a link to change the username and password' do
      expect(rendered).to match 'Сменить имя и пароль'
    end
    it 'render partial _game' do
      expect(rendered).to match 'User game goes here'
    end
  end

  context 'when the user views someone else`s page' do
    before do
      assign(:user, FactoryBot.build_stubbed(:user, name: 'User2'))

      render
    end

    it 'returns user name' do
      expect(rendered).to match 'User2'
    end

    it 'don`t returns a link to change the username and password' do
      expect(rendered).not_to match('Сменить имя и пароль')
    end
  end
end
