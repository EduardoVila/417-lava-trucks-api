# frozen_string_literal: true

module LavaTrucks
  class Summary
    def self.call(from, to)
      new(from, to).call
    end

    def initialize(from, to)
      @period = from..to
      @washes = Repository.new('washes').all
      @services = within(@washes, 'date')
      @pending = @washes.reject { |wash| wash['paid'] }
    end

    def call
      financials.merge(count: @services.length,
                       pending_cents: total(@pending),
                       pending_count: @pending.length,
                       ticket_cents: ticket,
                       by_service: ServiceTypes.all.map { |service| service_total(service['code'], service['name']) })
    end

    private

    def financials
      revenue = total(@services)
      received = total(within(@washes.select { |wash| wash['paid'] }, 'paid_on'))
      spent = total(within(Repository.new('expenses').all, 'date'))
      { revenue_cents: revenue, received_cents: received,
        expenses_cents: spent, result_cents: revenue - spent,
        cash_cents: received - spent }
    end

    def ticket
      @services.empty? ? 0 : (total(@services).to_f / @services.length).round
    end

    def service_total(kind, name)
      rows = @services.select { |wash| wash['service'] == kind }
      { service: kind, name: name, count: rows.length, amount_cents: total(rows) }
    end

    def within(rows, key)
      rows.select { |row| @period.cover?(row[key]) }
    end

    def total(rows)
      rows.sum { |row| row['amount_cents'] }
    end
  end
end
