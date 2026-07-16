%% 
%% 6. Helper function: ISI - aware 4 - state Viterbi soft - decision sequence detection
%% 
function det_symb = viterbi_decode_isi(obs_matrix)
    global ref_metric last_pm;
    [M_v, T] = size(obs_matrix);
    [pathMetric, back] = deal(zeros(M_v, T));

    %% ====
    %% Vectorized precomputation: normalized reference templates
    %% ====
    % ref_metric is (prev_g, curr_g, branch_idx) = M_v x M_v x M_v
    % Compute L2 norm of each reference vector over the branch dimension
    ref_norms = squeeze(sqrt(sum(ref_metric.^2, 3))); % M_v x M_v
    ref_normed = zeros(size(ref_metric));
    for p = 1:M_v
        for c = 1:M_v
            if ref_norms(p,c) > 1e-6
                ref_normed(p,c,:) = ref_metric(p,c,:)/ref_norms(p,c);
            end
        end
    end
    % Flatten to branch x (M_v*M_v) for matrix multiplication
    % After permute: dimension = (branch, prev, curr)
    ref_all = reshape(permute(ref_normed, [3, 1, 2]), M_v, []);

    %% ====
    %% Vectorized precomputation: normalized observation vectors
    %% ====
    obs_norms = vecnorm(obs_matrix, 2, 1);  % 1 x T
    obs_normed = obs_matrix ./ obs_norms;   % broadcast normalization
    obs_normed(:, obs_norms < 1e-6) = 0;    % handle zero - norm vectors

    %% ====
    % t == 1: initialize (prev = 0, i.e., prev_g = 0, prev_idx = 1)
    %% ====
    if isinf(last_pm)
        pathMetric(:, 1) = (obs_normed(:, 1)' * ref_all(:, 1:M_v:M_v*M_v)).';
    else
        branch_all = reshape(obs_normed(:, 1)' * ref_all, M_v, M_v);
        val = last_pm + branch_all;
        pm_t = max(val, [], 1);             % 1 x M_v
        pathMetric(:, 1) = pm_t.';          % M_v x 1
        pathMetric(:, 1) = pathMetric(:, 1) - max(pathMetric(:, 1)); % prevent overflow
    end

    %% ====
    % t = 2:T: fully vectorized forward recursion
    % For each t, compute all M_v x M_v branch metrics in one matrix product
    %% ====
    for t = 2:T
        % obs_normed(:, t)' (1 x M_v) * ref_all (M_v x M_v^2) -> 1 x M_v^2
        % reshape to M_v x M_v: rows = prev, cols = curr
        branch_all = reshape(obs_normed(:, t)' * ref_all, M_v, M_v);

        % val(prev, curr) = pathMetric(prev, t - 1) + branch(prev, curr)
        % pathMetric(:, t - 1) is M_v x 1, auto - broadcast to each column of M_v x M_v
        val = pathMetric(:, t - 1) + branch_all;

        % max over rows (prev) for each column (curr)
        [pm_t, back_t] = max(val, [], 1);   % 1 x M_v
        pathMetric(:, t) = pm_t.';          % M_v x 1
        back(:, t) = back_t.';              % M_v x 1
        pathMetric(:, t) = pathMetric(:, t) - max(pathMetric(:, t)); % prevent overflow
    end
    last_pm = pathMetric(:, t); % Store last pm of current Nsegment

    %% ====
    % Traceback (sequential dependency, loop retained)
    %% ====
    det_symb = zeros(T, 1);
    [~, det_symb(end)] = max(pathMetric(:, end));
    for t = T-1:-1:1
        det_symb(t) = back(det_symb(t+1), t+1);
    end
    det_symb = det_symb - 1; % 0 - based Gray
end