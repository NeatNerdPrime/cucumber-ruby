# frozen_string_literal: true

require 'spec_helper'
require 'cucumber/multiline_argument/data_table'

module Cucumber
  module MultilineArgument
    describe DataTable do
      subject(:table) { described_class.from([%w[one four seven], %w[4444 55555 666666]]) }

      it 'has rows' do
        expect(table.cells_rows[0].map(&:value)).to eq(%w[one four seven])
      end

      it 'has columns' do
        expect(table.columns[1].map(&:value)).to eq(%w[four 55555])
      end

      it 'has same cell objects in rows and columns' do
        expect(table.cells_rows[1][2]).to eq(table.columns[2][1])
      end

      it 'is convertible to an array of hashes' do
        expect(table.hashes).to eq([{ 'one' => '4444', 'four' => '55555', 'seven' => '666666' }])
      end

      it 'accepts symbols as keys for the hashes' do
        expect(table.hashes.first[:one]).to eq('4444')
      end

      it 'returns the row values in order' do
        expect(table.rows.first).to eq(%w[4444 55555 666666])
      end

      describe '#symbolic_hashes' do
        it 'converts data table to an array of hashes with symbols as keys' do
          ast_table = Cucumber::Core::Test::DataTable.new([['foo', 'Bar', 'Foo Bar'], %w[1 22 333]])
          data_table = described_class.new(ast_table)

          expect(data_table.symbolic_hashes).to eq([{ foo: '1', bar: '22', foo_bar: '333' }])
        end

        it 'is able to be accessed multiple times' do
          table.symbolic_hashes

          expect { table.symbolic_hashes }.not_to raise_error
        end

        it 'does not interfere with use of #hashes' do
          table.symbolic_hashes

          expect { table.hashes }.not_to raise_error
        end
      end

      describe '#map_column' do
        it 'allows mapping columns' do
          new_table = table.map_column('one', &:to_i)

          expect(new_table.hashes.first['one']).to eq(4444)
        end

        it 'applies the block once to each value when #rows are interrogated' do
          rows = ['value']
          table = described_class.from [['header'], rows]
          count = 0
          table.map_column('header') { count += 1 }.rows

          expect(count).to eq(rows.length)
        end

        it 'allows mapping columns taking a symbol as the column name' do
          new_table = table.map_column(:one, &:to_i)

          expect(new_table.hashes.first['one']).to eq 4444
        end

        it 'allows mapping columns and modify the rows as well' do
          new_table = table.map_column(:one, &:to_i)

          expect(new_table.rows.first).to include(4444)
          expect(new_table.rows.first).not_to include('4444')
        end

        it 'passes silently once #hashes are interrogated if a mapped column does not exist in non-strict mode' do
          expect do
            new_table = table.map_column('two', strict: false, &:to_i)
            new_table.hashes
          end.not_to raise_error
        end

        it 'fails once #hashes are interrogated if a mapped column does not exist in strict mode' do
          expect do
            new_table = table.map_column('two', strict: true, &:to_i)
            new_table.hashes
          end.to raise_error('The column named "two" does not exist')
        end

        it 'returns a new table' do
          expect(table.map_column(:one, &:to_i)).not_to eq(table)
        end
      end

      describe '#match' do
        it 'returns nil if headers do not match' do
          expect(table.match('does,not,match')).to be_nil
        end

        it 'requires a table: prefix on match' do
          expect(table.match('table:one,four,seven')).not_to be_nil
        end

        it 'does not match if no table: prefix on match' do
          expect(table.match('one,four,seven')).to be_nil
        end
      end

      describe '#transpose' do
        it 'is convertible in to an array where each row is a hash' do
          expect(table.transpose.hashes[0]).to eq('one' => 'four', '4444' => '55555')
        end
      end

      describe '#rows_hash' do
        it 'returns a hash of the rows' do
          table = described_class.from([%w[one 1111], %w[two 22222]])

          expect(table.rows_hash).to eq('one' => '1111', 'two' => '22222')
        end

        it "fails if the table doesn't have two columns" do
          faulty_table = described_class.from([%w[one 1111 abc], %w[two 22222 def]])

          expect { faulty_table.rows_hash }.to raise_error('The table must have exactly 2 columns')
        end

        it 'supports header and column mapping' do
          table = described_class.from([%w[one 1111], %w[two 22222]])
          t2 = table.map_headers({ 'two' => 'Two' }, &:upcase).map_column('two', strict: false, &:to_i)

          expect(t2.rows_hash).to eq('ONE' => '1111', 'Two' => 22_222)
        end
      end

      describe '#map_headers' do
        subject(:table) { described_class.from([%w[ANT ANTEATER], %w[4444 55555]]) }

        it 'renames the columns to the specified values in the provided hash' do
          table2 = table.map_headers('ANT' => :three)

          expect(table2.hashes.first[:three]).to eq('4444')
        end

        it 'allows renaming columns using regexp' do
          table2 = table.map_headers(/^ANT$|^BEE$/ => :three)

          expect(table2.hashes.first[:three]).to eq('4444')
        end

        it 'copies column mappings' do
          table2 = table.map_column('ANT', &:to_i)
          table3 = table2.map_headers('ANT' => 'three')

          expect(table3.hashes.first['three']).to eq(4444)
        end

        it 'takes a block and operates on all the headers with it' do
          table2 = table.map_headers(&:downcase)

          expect(table2.hashes.first.keys).to match %w[ant anteater]
        end

        it 'treats the mappings in the provided hash as overrides when used with a block' do
          table2 = table.map_headers('ANT' => 'foo', &:downcase)

          expect(table2.hashes.first.keys).to match %w[foo anteater]
        end
      end

      describe 'diff!' do
        it 'detects a complex diff' do
          t1 = described_class.from(%(
            | 1         | 22          | 333         | 4444         |
            | 55555     | 666666      | 7777777     | 88888888     |
            | 999999999 | 0000000000  | 01010101010 | 121212121212 |
            | 4000      | ABC         | DEF         | 50000        |
          ))

          t2 = described_class.from(%(
            | a     | 4444     | 1         |
            | bb    | 88888888 | 55555     |
            | ccc   | xxxxxxxx | 999999999 |
            | dddd  | 4000     | 300       |
            | e     | 50000    | 4000      |
          ))
          expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
            expect(error.table.to_s(indent: 14, color: false)).to eq %{
              |     1         | (-) 22         | (-) 333         |     4444         | (+) a    |
              |     55555     | (-) 666666     | (-) 7777777     |     88888888     | (+) bb   |
              | (-) 999999999 | (-) 0000000000 | (-) 01010101010 | (-) 121212121212 | (+)      |
              | (+) 999999999 | (+)            | (+)             | (+) xxxxxxxx     | (+) ccc  |
              | (+) 300       | (+)            | (+)             | (+) 4000         | (+) dddd |
              |     4000      | (-) ABC        | (-) DEF         |     50000        | (+) e    |
            }
          end
        end

        it 'does not change table when diffed with identical' do
          t = described_class.from(%(

            |a|b|c|
            |d|e|f|
            |g|h|i|
          ))
          t.diff!(t.dup)
          expect(t.to_s(indent: 12, color: false)).to eq %(
            |     a |     b |     c |
            |     d |     e |     f |
            |     g |     h |     i |
          )
        end

        context 'with empty tables' do
          it 'allows diffing empty tables' do
            t1 = described_class.from([[]])
            t2 = described_class.from([[]])
            expect { t1.diff!(t2) }.not_to raise_error
          end

          it 'is able to diff when the right table is empty' do
            t1 = described_class.from(%(
              |a|b|c|
              |d|e|f|
              |g|h|i|
            ))
            t2 = described_class.from([[]])
            expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
              expect(error.table.to_s(indent: 16, color: false)).to eq %{
                | (-) a | (-) b | (-) c |
                | (-) d | (-) e | (-) f |
                | (-) g | (-) h | (-) i |
              }
            end
          end

          it 'should be able to diff when the left table is empty' do
            t1 = described_class.from([[]])
            t2 = described_class.from(%(
              |a|b|c|
              |d|e|f|
              |g|h|i|
            ))
            expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
              expect(error.table.to_s(indent: 16, color: false)).to eq %{
                | (+) a | (+) b | (+) c |
                | (+) d | (+) e | (+) f |
                | (+) g | (+) h | (+) i |
              }
            end
          end
        end

        context 'with duplicate header values' do
          it 'raises no error for two identical tables' do
            t = described_class.from(%(
            |a|a|c|
            |d|e|f|
            |g|h|i|
                               ))
            t.diff!(t.dup)
            expect(t.to_s(indent: 12, color: false)).to eq %(
            |     a |     a |     c |
            |     d |     e |     f |
            |     g |     h |     i |
          )
          end

          it 'detects a diff in one cell' do
            t1 = described_class.from(%(
            |a|a|c|
            |d|e|f|
            |g|h|i|
                                ))
            t2 = described_class.from(%(
            |a|a|c|
            |d|oops|f|
            |g|h|i|
                                ))
            expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
              expect(error.table.to_s(indent: 16, color: false)).to eq %{
                |     a |     a    |     c |
                | (-) d | (-) e    | (-) f |
                | (+) d | (+) oops | (+) f |
                |     g |     h    |     i |
              }
            end
          end

          it 'detects missing columns' do
            t1 = described_class.from(%(
            |a|a|b|c|
            |d|d|e|f|
            |g|g|h|i|
                                ))
            t2 = described_class.from(%(
            |a|b|c|
            |d|e|f|
            |g|h|i|
                                ))
            expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
              expect(error.table.to_s(indent: 16, color: false)).to eq %{
                |     a | (-) a |     b |     c |
                |     d | (-) d |     e |     f |
                |     g | (-) g |     h |     i |
              }
            end
          end

          it 'detects surplus columns' do
            t1 = described_class.from(%(
            |a|b|c|
            |d|e|f|
            |g|h|i|
                                ))
            t2 = described_class.from(%(
            |a|b|a|c|
            |d|e|d|f|
            |g|h|g|i|
                                ))
            expect { t1.diff!(t2, surplus_col: true) }.to raise_error(DataTable::Different) do |error|
              expect(error.table.to_s(indent: 16, color: false)).to eq %{
                |     a |     b |     c | (+) a |
                |     d |     e |     f | (+) d |
                |     g |     h |     i | (+) g |
              }
            end
          end
        end

        it 'inspects missing and surplus cells' do
          t1 = described_class.from([
                                      %w[name male lastname swedish],
                                      %w[aslak true hellesøy false]
                                    ])
          t2 = described_class.from([
                                      %w[name male lastname swedish],
                                      ['aslak', true, 'hellesøy', false]
                                    ])
          expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
            expect(error.table.to_s(indent: 14, color: false)).to eq %{
              |     name  |     male       |     lastname |     swedish     |
              | (-) aslak | (-) (i) "true" | (-) hellesøy | (-) (i) "false" |
              | (+) aslak | (+) (i) true   | (+) hellesøy | (+) (i) false   |
            }
          end
        end

        it 'allows column mapping of target before diffing' do
          t1 = described_class.from([
                                      %w[name male],
                                      %w[aslak true]
                                    ])
          t2 = described_class.from([
                                      %w[name male],
                                      ['aslak', true]
                                    ])
          t1.map_column('male') { |m| m == 'true' }.diff!(t2)
          expect(t1.to_s(indent: 12, color: false)).to eq %(
            |     name  |     male |
            |     aslak |     true |
          )
        end

        it 'allows column mapping of argument before diffing' do
          t1 = described_class.from([
                                      %w[name male],
                                      ['aslak', true]
                                    ])
          t2 = described_class.from([
                                      %w[name male],
                                      %w[aslak true]
                                    ])
          t2.diff!(t1.map_column('male') { 'true' })
          expect(t1.to_s(indent: 12, color: false)).to eq %(
            |     name  |     male |
            |     aslak |     true |
          )
        end

        it 'allows header mapping before diffing' do
          t1 = described_class.from([
                                      %w[Name Male],
                                      %w[aslak true]
                                    ])
          t1 = t1.map_headers('Name' => 'name', 'Male' => 'male')
          t1 = t1.map_column('male') { |m| m == 'true' }

          t2 = described_class.from([
                                      %w[name male],
                                      ['aslak', true]
                                    ])
          t1.diff!(t2)
          expect(t1.to_s(indent: 12, color: false)).to eq %(
            |     name  |     male |
            |     aslak |     true |
          )
        end

        it 'detects seemingly identical tables as different' do
          t1 = described_class.from([
                                      %w[X Y],
                                      %w[2 1]
                                    ])
          t2 = described_class.from([
                                      %w[X Y],
                                      [2, 1]
                                    ])
          expect { t1.diff!(t2) }.to raise_error(DataTable::Different) do |error|
            expect(error.table.to_s(indent: 14, color: false)).to eq %{
              |     X       |     Y       |
              | (-) (i) "2" | (-) (i) "1" |
              | (+) (i) 2   | (+) (i) 1   |
            }
          end
        end

        it 'does not allow mappings that match more than 1 column' do
          t1 = described_class.from([
                                      %w[Cuke Duke],
                                      %w[Foo Bar]
                                    ])
          expect do
            t1 = t1.map_headers(/uk/ => 'u')
            t1.hashes
          end.to raise_error(%(2 headers matched /uk/: ["Cuke", "Duke"]))
        end

        describe 'raising' do
          before do
            @t = described_class.from(%(
              | a | b |
              | c | d |
            ))
            expect(@t).not_to eq nil
          end

          it 'raises on missing rows' do
            t = described_class.from(%(
              | a | b |
            ))
            expect { @t.dup.diff!(t) }.to raise_error(DataTable::Different)
            expect { @t.dup.diff!(t, missing_row: false) }.not_to raise_error
          end

          it 'does not raise on surplus rows when surplus is at the end' do
            t = described_class.from(%(
              | a | b |
              | c | d |
              | e | f |
            ))
            expect { @t.dup.diff!(t) }.to raise_error(DataTable::Different)
            expect { @t.dup.diff!(t, surplus_row: false) }.not_to raise_error
          end

          it 'does not raise on surplus rows when surplus is interleaved' do
            t1 = described_class.from(%(
              | row_1 | row_2 |
              | four  | 4     |
            ))
            t2 = described_class.from(%(
              | row_1 | row_2 |
              | one   | 1     |
              | two   | 2     |
              | three | 3     |
              | four  | 4     |
              | five  | 5     |
            ))
            expect { t1.dup.diff!(t2) }.to raise_error(DataTable::Different)
            expect { t1.dup.diff!(t2, surplus_row: false) }.not_to raise_error
          end

          it 'raises on missing columns' do
            t = described_class.from(%(
              | a |
              | c |
            ))
            expect { @t.dup.diff!(t) }.to raise_error(DataTable::Different)
            expect { @t.dup.diff!(t, missing_col: false) }.not_to raise_error
          end

          it 'does not raise on surplus columns' do
            t = described_class.from(%(
              | a | b | x |
              | c | d | y |
            ))
            expect { @t.dup.diff!(t) }.not_to raise_error
            expect { @t.dup.diff!(t, surplus_col: true) }.to raise_error(DataTable::Different)
          end

          it 'does not raise on misplaced columns' do
            t = described_class.from(%(
              | b | a |
              | d | c |
            ))
            expect { @t.dup.diff!(t) }.not_to raise_error
            expect { @t.dup.diff!(t, misplaced_col: true) }.to raise_error(DataTable::Different)
          end
        end

        it 'can compare to an Array' do
          t = described_class.from(%(
            | b | a |
            | d | c |
          ))
          other = [%w[b a], %w[d c]]

          expect { t.diff!(other) }.not_to raise_error
        end
      end

      describe '#from' do
        it 'allows Array of Hash' do
          t1 = described_class.from([{ 'name' => 'aslak', 'male' => 'true' }])
          expect(t1.to_s(indent: 12, color: false)).to eq %(
            |     male |     name  |
            |     true |     aslak |
          )
        end
      end
    end
  end
end
