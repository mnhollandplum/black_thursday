require './test/test_helper'
require './lib/merchant_repository'


class MerchantRepositoryTest < Minitest::Test
  def test_it_exists
    merchant_repository = MerchantRepository.new('./data/merchants.csv')

    assert_instance_of MerchantRepository, merchant_repository
  end

  def test_merchant_repository_has_merchants
    merchant_repository = MerchantRepository.new('./data/merchants.csv')

    assert_equal 475, merchant_repository.all.count
    assert_instance_of Array, merchant_repository.all
    assert merchant_repository.all.all? { |merchant| merchant.is_a?(Merchant)}
    assert_equal "Shopin1901", merchant_repository.all.first.name
  end

  def test_it_can_find_merchant_by_id
    merchant_repository = MerchantRepository.new('./data/merchants.csv')

    actual = merchant_repository.find_by_id(12334112)

    assert_instance_of Merchant, actual
    assert_equal "Candisart", actual.name
    assert_equal 12334112, actual.id
  end

  def test_returns_nil_when_no_match_is_found
    merchant_repository = MerchantRepository.new('./data/merchants.csv')

    actual = merchant_repository.find_by_id(99999)

    assert_nil actual
  end
  #
  def test_it_can_find_merchant_by_name
    merchant_repository = MerchantRepository.new('./data/merchants.csv')

    actual = [merchant_repository.all[0]]

    assert_equal merchant_repository.find_by_name("Shopin1901"), actual
  end


end
