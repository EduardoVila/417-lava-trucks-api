# frozen_string_literal: true

module LavaTrucks
  class Repository
    def initialize(table)
      raise ArgumentError unless %w[washes expenses].include?(table)

      @table = table
    end

    def all
      query = @table == 'washes' ? "SELECT washes.*, users.name AS user_name FROM washes LEFT JOIN users ON users.id = washes.user_id ORDER BY washes.date DESC, washes.id DESC" : "SELECT * FROM #{@table} ORDER BY date DESC, id DESC"
      db.execute(query).map { |row| serialize(row) }
    end

    def find(id)
      query = @table == 'washes' ? 'SELECT washes.*, users.name AS user_name FROM washes LEFT JOIN users ON users.id = washes.user_id WHERE washes.id = ?' : "SELECT * FROM #{@table} WHERE id = ?"
      row = db.get_first_row(query, [id])
      row && serialize(row)
    end

    def create(attributes)
      columns = attributes.keys.join(', ')
      placeholders = (['?'] * attributes.length).join(', ')
      db.execute("INSERT INTO #{@table} (#{columns}) VALUES (#{placeholders}) RETURNING id", attributes.values)
      find(db.last_insert_row_id)
    end

    def update(id, attributes)
      columns = attributes.keys.map { |key| "#{key} = ?" }.join(', ')
      db.execute("UPDATE #{@table} SET #{columns} WHERE id = ?", [*attributes.values, id])
      find(id)
    end

    def delete(id)
      db.execute("DELETE FROM #{@table} WHERE id = ?", [id])
    end

    private

    def db
      Database.connection
    end

    def serialize(row)
      row['paid'] = row['paid'] == 1 if @table == 'washes'
      row['service_name'] ||= ServiceTypes.find(row['service'])&.fetch('name', row['service']) if @table == 'washes'
      row
    end
  end
end
