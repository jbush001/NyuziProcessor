

module testbench(input clk, input reset);

    localparam NUM_REQUESTERS = 4;

    logic[NUM_REQUESTERS - 1:0] request;
    logic update_lru;
    logic[NUM_REQUESTERS - 1:0] grant_oh;
    int count;

    rr_arbiter #(.NUM_REQUESTERS(4)) rr_arbiter(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            count <= 0;
            request <= 0;
            update_lru <= 0;
        end
        else
        begin
            count <= count + 1;
            case (count)
                // Make all inputs request
                0:
                begin
                    request <= 15;
                    update_lru <= 1;
                end

                // Test that it cycles through all of them
                1:  assert(grant_oh == 4'b0001);
                2:  assert(grant_oh == 4'b0010);
                3:  assert(grant_oh == 4'b0100);
                4:  assert(grant_oh == 4'b1000);
                5:
                begin
                    assert(grant_oh == 4'b0001);
                    update_lru <= 0;
                end

                // Update LRU cleared, ensure it doesn't update
                6: assert(grant_oh == 4'b0010);
                7: assert(grant_oh == 4'b0010);
                8: assert(grant_oh == 4'b0010);
                9:
                begin
                    assert(grant_oh == 4'b0010);

                    update_lru <= 1;
                    request <= 4'b0101;
                end

                10: assert(grant_oh == 4'b0100);
                11: assert(grant_oh == 4'b0001);
                12: assert(grant_oh == 4'b0100);
                13:
                begin
                    assert(grant_oh == 4'b0001);
                    request <= 4'b1010;
                end

                14: assert(grant_oh == 4'b0010);
                15: assert(grant_oh == 4'b1000);
                16: assert(grant_oh == 4'b0010);
                17:
                begin
                    assert(grant_oh == 4'b1000);
                    request <= 4'b0000;
                end

                // No requestors
                18: assert(grant_oh == 4'b0000);

                19:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
