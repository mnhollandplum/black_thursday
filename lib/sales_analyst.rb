require 'pry'
require 'date'

class SalesAnalyst
  attr_reader :se

  def initialize(sales_engine)
    @se = sales_engine
  end

  #------Iteration 1 Methods--------#

  def average_items_per_merchant
    (@se.items.all.count.to_f/@se.merchants.all.count).round(2)
  end

  def average_items_per_merchant_standard_deviation
    hash = item_count_per_merchant_id
    differences_squared = square_differences(hash.values, average_items_per_merchant)
    sum = sum(differences_squared)
    sum_div = sum/hash.count
    Math.sqrt(sum_div).round(2)
  end

  def merchants_with_high_item_count
    hash = item_count_per_merchant_id
    merchant_ids = merchant_ids_with_high_item_count(hash)
    merchants_from_ids(merchant_ids)
  end

  def average_item_price_for_merchant(id)
    prices = find_prices_for_merchant(id)
    sum = sum(prices)
    (sum/prices.count).round(2)
  end

  def average_average_price_per_merchant
    summed = @se.merchants.all.inject(0) do |sum, merchant|
      sum + average_item_price_for_merchant(merchant.id)
    end
    (summed/@se.merchants.all.count).round(2)
  end

  def golden_items
    prices = find_prices
    average = sum(prices)/prices.count
    differences_squared = square_differences(prices, average)
    sum = sum(differences_squared)
    sum_div = sum/prices.count
    std_dev = Math.sqrt(sum_div).round(2)
    threshold = average + std_dev * 2
    find_golden_items(@se.items.all, threshold)
  end

 #-----Iteration 2 Methods-----#

 def average_invoices_per_merchant
   (@se.invoices.all.count.to_f/@se.merchants.all.count).round(2)
 end

  def average_invoices_per_merchant_standard_deviation
    hash = invoice_count_per_merchant_id
    differences_squared = square_differences(hash.values, average_invoices_per_merchant)
    sum = sum(differences_squared)
    sum_div = sum/hash.count
    Math.sqrt(sum_div).round(2)
  end

  def top_merchants_by_invoice_count
    above_sd = two_above_standard_deviation
    invoice_count_per_merchant_id.map do |id, count|
      @se.merchants.find_by_id(id) if count >= above_sd
    end.compact
  end

  def bottom_merchants_by_invoice_count
    invoice_count_per_merchant_id.map do |id, count|
      @se.merchants.find_by_id(id) if count <= two_below_standard_deviation
    end.compact
  end

  def top_days_by_invoice_count
    highest_day = []
    above_sd = one_above_sd_for_day
    number_of_invoices_per_day.map do |day, count|
      highest_day << day if count > above_sd
    end
    highest_day.compact
  end

  def invoice_status(status)
    decimal = invoices_grouped_by_status[status]
    (decimal.to_f / @se.invoices.all.count * 100).round(2)
  end

  # -----Iteration 3 Methods----- #

  def invoice_paid_in_full?(invoice_id)
    transactions_by_invoice_id = @se.transactions.find_all_by_invoice_id(invoice_id)
    transactions_by_invoice_id.any? do |transaction|
      transaction.result == :success
    end
  end

  def invoice_total(invoice_id)
    invoice_items = @se.invoice_items.find_all_by_invoice_id(invoice_id)
    total_revenue_by_item(invoice_items)
  end

  # -----Iteration 4 Methods----- #

  def total_revenue_by_date(date)
    @se.invoices.all.inject(0) do |sum, invoice|
      if invoice.created_at.strftime("%Y-%m-%d") == date.strftime("%Y-%m-%d") && invoice_paid_in_full?(invoice.id)
        sum += invoice_total(invoice.id)
      end
      sum
    end
  end

  def top_revenue_earners(x = 20)
    merchants_ranked_by_revenue[0..x-1]
  end

  def merchants_with_pending_invoices
    pending_invoices = @se.invoices.all.map do |invoice|
      invoice.merchant_id unless invoice_paid_in_full?(invoice.id)
    end.compact
    pending_invoices.map do |merchant_id|
      @se.merchants.find_by_id(merchant_id)
    end.uniq
  end

  def merchants_with_only_one_item
	  hash = merchant_ids_with_count
	  ids = merchant_ids_with_one_item(hash)
	  merchants_from_ids(ids)
  end

  def merchants_with_only_one_item_registered_in_month(month)
    hash = merchant_ids_with_count_for_month(month)
    ids = merchant_ids_with_one_item(hash)
    merchants_from_ids(ids)
  end

  def revenue_by_merchant(merchant_id)
	  merchant_invoices = invoices_for_merchant_id(merchant_id)
    merchant_invoices.inject(0) do |sum, invoice|
		  sum + invoice_total(invoice.id)
	  end
  end

  def most_sold_item_for_merchant(merchant_id)
    merchant_invoices = invoices_for_merchant_id(merchant_id)
    invoice_ids = ids_from_invoices(merchant_invoices)
    items_hash = invoice_items_with_quantities(invoice_ids)
    max_item_quantity = find_max_from_hash(items_hash)[1]
    top_item_ids = top_items_from_hash(items_hash, max_item_quantity)

    top_item_ids.map do |item_id|
      @se.items.find_by_id(item_id[0])
    end
  end

  def best_item_for_merchant(merchant_id)
    merchant_invoices = invoices_for_merchant_id(merchant_id)
    invoice_ids = ids_from_invoices(merchant_invoices)
    items_hash = invoice_items_with_revenue(invoice_ids)
    max_revenue_item = find_max_from_hash(items_hash)

    @se.items.find_by_id(max_revenue_item[0])
  end

  #-- Iteration 1 Helper Methods --#

  def item_count_per_merchant_id
    hash = Hash.new(0)
    @se.items.all.each do |item|
      hash[item.merchant_id] += 1
    end
    hash
  end

  def square_differences(values,average)
    values.map do |value|
      (value-average)**2
    end
  end

  def sum(numbers)
    numbers.inject(0) do |sum, num|
      sum + num
    end
  end

  def merchant_ids_with_high_item_count(hash)
    threshold = average_items_per_merchant +
                average_items_per_merchant_standard_deviation
    hash.find_all do |key, value|
      value > threshold
    end
  end

  def merchants_from_ids(ids)
    ids.map do |id, value|
      @se.merchants.find_by_id(id)
    end
  end

  def find_prices_for_merchant(id)
    prices = []
    @se.items.all.each do |item|
      prices << item.unit_price if item.merchant_id == id
    end
    prices
  end

  def average(numbers)
    sum(numbers)/numbers.count
  end

  def find_prices
    @se.items.all.inject([]) do |array, item|
      array << item.unit_price
    end
  end

  def find_golden_items(items, threshold)
    items.find_all do |item|
      item.unit_price > threshold
    end
  end

  #--Iteration 2 Helper Methods--#

  def invoice_count_per_merchant_id
    hash = Hash.new(0)
    @se.invoices.all.each do |invoice|
      hash[invoice.merchant_id] += 1
    end
    hash
  end

  def two_above_standard_deviation
    (average_invoices_per_merchant_standard_deviation * 2) + average_invoices_per_merchant
  end

  def two_below_standard_deviation
    average_invoices_per_merchant -
    (average_invoices_per_merchant_standard_deviation * 2)
  end

  def invoices_grouped_by_status
    group_status = @se.invoices.all.group_by do |invoice|
      invoice.status
    end
    group_status.each do |status, invoices|
      group_status[status] = invoices.count
    end
  end

  def one_above_sd_for_day
    (calculate_sd_by_day * 1) + average_invoices_per_day
  end

  def calculate_sd_by_day
    array = number_of_invoices_per_day.values
    average = average_invoices_per_day
    standard_deviation(array, average)
  end

  def group_invoices_by_days_of_the_week
    @se.invoices.all.group_by do |invoice|
      invoice.created_at.strftime('%A')
    end
  end

  def number_of_invoices_per_day
    invoice_by_day = Hash.new(0)
    group_invoices_by_days_of_the_week.each do |day, invoices|
      invoice_by_day[day] = invoices.count
    end
    invoice_by_day
  end

  def average_invoices_per_day
    (@se.invoices.all.count.to_f/group_invoices_by_days_of_the_week.count).round(2)
  end

  def differences_by_day(key)
    difference = group_invoices_by_days_of_the_week[key].count - average_invoices_per_day
    difference.round(2)
  end

  def  differences_by_day_squared(key)
    squared = differences_by_day(key) ** 2
    squared.round(2)
  end

  def standard_deviation(array, average)
    count_minus_one = (array.count - 1)
    sum = array.reduce(0.0) do |total, amount|
      total + (amount - average) ** 2
    end
    ((sum / count_minus_one) ** (1.0 / 2)).round(2)
  end

#-----Iteration 3 Helper Method -----#

  def total_revenue_by_item(invoice_items)
    invoice_items.inject(0) do |sum, num|
      sum + (num.quantity.to_i * num.unit_price)
    end
  end

#-----Iteration 4 Helper Method -----#

  def merchants_ranked_by_revenue
    hash = Hash.new()
    @se.merchants.all.each do |merchant|
      hash[merchant] = revenue_by_merchant(merchant.id)
    end

    hash.sort_by do |merchant, revenue|
      revenue * -1
    end.transpose[0]
  end

  def merchant_ids_with_count
    hash = Hash.new(0)
    @se.items.all.each do |item|
      hash[item.merchant_id] += 1
    end
    hash
  end

  def merchant_ids_with_count_for_month(month)
    hash = Hash.new(0)
    @se.items.all.each do |item|
      if @se.merchants.find_by_id(item.merchant_id).created_at.strftime("%B") == month
        hash[item.merchant_id] += 1
      end
    end
    hash
  end

  def merchant_ids_with_one_item(hash)
    hash.find_all do |merchant_id, amount|
      amount == 1
    end.transpose[0]
  end

  def invoices_for_merchant_id(merchant_id)
    @se.invoices.all.find_all do |invoice|
		  invoice.merchant_id == merchant_id && invoice_paid_in_full?(invoice.id)
	  end
  end

  def ids_from_invoices(invoices)
    invoices.map do |invoice|
      invoice.id
    end
  end

  def invoice_items_with_quantities(invoice_ids)
    items_hash = Hash.new(0)
    @se.invoice_items.all.each do |ii|
      if invoice_ids.include?(ii.invoice_id)
        items_hash[ii.item_id] += ii.quantity
      end
    end
    items_hash
  end

  def invoice_items_with_revenue(invoice_ids)
    items_hash = Hash.new(0)
    @se.invoice_items.all.each do |ii|
      if invoice_ids.include?(ii.invoice_id)
        items_hash[ii.item_id] += (ii.quantity * ii.unit_price)
      end
    end
    items_hash
  end

  def find_max_from_hash(hash)
    hash.max_by do |item_id, value|
      value
    end
  end

  def top_items_from_hash(hash, max_item_quantity)
    hash.find_all do |item_id, quantity|
      quantity == max_item_quantity
    end
  end

end
