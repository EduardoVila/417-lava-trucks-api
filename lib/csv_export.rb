# frozen_string_literal: true

module LavaTrucks
  class CsvExport
    COLUMNS = {
      'washes' => %w[id date time customer plate service amount_cents stage paid paid_on payment_method notes],
      'expenses' => %w[id date description category amount_cents payment_method notes]
    }.freeze

    def self.call(kind, rows)
      columns = COLUMNS.fetch(kind)
      output = CSV.generate(col_sep: ';') do |csv|
        csv << columns
        rows.each { |row| csv << columns.map { |key| cell(row[key]) } }
      end
      "\uFEFF#{output}"
    end

    def self.cell(value)
      text = value.to_s
      text.match?(/\A\s*[=+@\-\t\r\n]/) ? "'#{text}" : text
    end
    private_class_method :cell
  end
end
