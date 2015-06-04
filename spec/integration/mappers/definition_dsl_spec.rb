require 'spec_helper'

describe 'Mapper definition DSL' do
  include_context 'users and tasks'

  let(:header) { mapper.header }

  before do
    setup.relation(:users) do
      def email_index
        project(:email)
      end
    end
  end

  describe 'default PORO mapper' do
    subject(:mapper) { rom.mappers.users.entity }

    before do
      setup.mappers do
        define(:users) do
          model name: 'Test::User'

          register_as :entity

          attribute :name
          attribute :email
        end
      end
    end

    it 'defines a constant for the model class' do
      expect(mapper.model).to be(Test::User)
    end

    it 'defines header with attributes' do
      expect(header.keys).to eql([:name, :email])
    end
  end

  describe 'excluding attributes' do
    context 'by setting :inherit_header to false' do
      subject(:mapper) { rom.mappers.users.email_index }

      before do
        setup.mappers do
          define(:users) do
            model name: 'Test::User'

            attribute :name
            attribute :email
          end

          define(:email_index, parent: :users, inherit_header: false) do
            model name: 'Test::UserWithoutName'
            attribute :email
          end
        end
      end

      it 'only maps provided attributes' do
        expect(header.keys).to eql([:email])
      end
    end
  end

  describe 'virtual relation mapper' do
    subject(:mapper) { rom.mappers.users.email_index }

    before do
      setup.mappers do
        define(:users) do
          model name: 'Test::User'

          attribute :name
          attribute :email
        end

        define(:email_index, parent: :users) do
          model name: 'Test::UserWithoutName'
          exclude :name
        end
      end
    end

    it 'inherits the attributes from the parent by default' do
      expect(header.keys).to eql([:name, :email])
    end

    it 'excludes an inherited attribute when requested' do
      name = header.attributes[:name]
      expect(name).to be_kind_of ROM::Header::Exclude
    end

    it 'builds a new model' do
      expect(mapper.model).to be(Test::UserWithoutName)
    end
  end

  describe 'wrapped relation mapper' do
    before do
      setup.relation(:tasks) do
        def with_user
          join(users)
        end
      end

      setup.mappers do
        define(:tasks) do
          model name: 'Test::Task'

          attribute :title
          attribute :priority
        end
      end
    end

    it 'allows defining wrapped attributes via options hash' do
      setup.mappers do
        define(:with_user, parent: :tasks) do
          model name: 'Test::TaskWithUser'

          attribute :title
          attribute :priority

          wrap user: [:email]
        end
      end

      rom = setup.finalize

      Test::TaskWithUser.send(:include, Equalizer.new(:title, :priority, :user))

      jane = rom.relation(:tasks).with_user.as(:with_user).to_a.last

      expect(jane).to eql(
        Test::TaskWithUser.new(
          title: 'be cool',
          priority: 2,
          user: { email: 'jane@doe.org' }
        )
      )
    end

    it 'allows defining wrapped attributes via options block' do
      setup.mappers do
        define(:with_user, parent: :tasks) do
          model name: 'Test::TaskWithUser'

          attribute :title
          attribute :priority

          wrap :user do
            attribute :email
          end
        end
      end

      rom = setup.finalize

      Test::TaskWithUser.send(:include, Equalizer.new(:title, :priority, :user))

      jane = rom.relation(:tasks).with_user.as(:with_user).to_a.last

      expect(jane).to eql(
        Test::TaskWithUser.new(
          title: 'be cool',
          priority: 2,
          user: { email: 'jane@doe.org' }
        )
      )
    end

    it 'allows defining wrapped attributes mapped to a model' do
      setup.mappers do
        define(:with_user, parent: :tasks) do
          model name: 'Test::TaskWithUser'

          attribute :title
          attribute :priority

          wrap :user do
            model name: 'Test::User'
            attribute :email
          end
        end
      end

      rom = setup.finalize

      Test::TaskWithUser.send(:include, Equalizer.new(:title, :priority, :user))
      Test::User.send(:include, Equalizer.new(:email))

      jane = rom.relation(:tasks).with_user.as(:with_user).to_a.last

      expect(jane).to eql(
        Test::TaskWithUser.new(
          title: 'be cool',
          priority: 2,
          user: Test::User.new(email: 'jane@doe.org')
        )
      )
    end
  end
end
