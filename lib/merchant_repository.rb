require_relative './merchant'
require_relative './repository'

class MerchantRepository < Repository
  def initialize(filepath)
    super()
    load_merchants(filepath)
  end

  def load_merchants(filepath)
    CSV.foreach(filepath, headers: true, header_converters: :symbol ) do |datum|
      @data << Merchant.new(datum)
    end
  end

  def find_by_id(id)
    @data.find do |datum|
      datum.id == id
    end
  end

  def find_all_by_name(name)
    all_merch_names = @data.select do |datum|
      datum.name.downcase.include?(name.downcase)
    end
    return all_merch_names
  end

  def create(new_merchant)
    highest_id = @data.max_by do |datum|
      datum.id
    end.id
    new_merchant_id = highest_id += 1
    new_merchant = Merchant.new(id: new_merchant_id,
                                name: new_merchant[:name])
    @data << new_merchant
    return new_merchant
  end

  def update(id, attributes)
    merchant = find_by_id(id)
    return if merchant.nil?
    attributes.each do |key, value|
      update_name(merchant, value) if key == :name
    end
  end

  def update_name(merchant, value)
    merchant.name = value
    merchant.updated_at = Time.now
  end

  def delete(id)
    merchant = find_by_id(id)
    @data.delete(merchant)
  end
end
