require "./spec_helper"

require "../src/postgis"

TEST_DB.exec "CREATE EXTENSION IF NOT EXISTS postgis"

describe PostGIS do
  it "decodes 2D points" do
    expect_decode "SELECT 'point(1 2)'::geography", PostGIS::Point2D.new(
      x: 1.0,
      y: 2.0,
    )

    # TODO: How do we test empty points?
    # expect_decode "SELECT 'point empty'::geography", PostGIS::Point2D.new(
    #   x: Float64::NAN,
    #   y: Float64::NAN,
    # )
  end

  it "decodes 3D points" do
    expect_decode "SELECT 'point(1 2 3)'::geography", PostGIS::Point3D.new(
      srid: 4326_u32,
      x: 1.0,
      y: 2.0,
      z: 3.0,
    )
  end

  it "decodes polygons" do
    expect_decode "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geography", PostGIS::Polygon2D.new([
      [
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
      ],
    ])
    # expect_decode "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geography", 0 # PostGIS::Circle.new()
  end

  it "decodes as part of DB::Serializable" do
    sql = <<-SQL
      SELECT
        '123 Main St' street,
        'Baltimore' city,
        'MD' state,
        '21201' zip,
        'point(1 2)'::geography coordinates
    SQL
    address = TEST_DB.query_one sql, as: Address
    address.coordinates.should eq PostGIS::Point2D.new(
      x: 1.0,
      y: 2.0,
    )
  end
end

private def expect_decode(query, as value : T) forall T
  TEST_DB
    .query_one(query, as: T)
    .should eq(value)
end

struct Address
  include DB::Serializable

  getter street : String
  getter city : String
  getter state : String
  getter zip : String
  getter coordinates : PostGIS::Point2D

  def initialize(@street, @city, @state, @zip, @coordinates)
  end
end
