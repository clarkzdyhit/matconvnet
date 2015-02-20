function [y,dzdg,dzdb] = vl_nnbnorm3(x,g,b,varargin)
% VL_NNBNORM  CNN batch normalisation

% Copyright (C) 2015 Karel Lenc
% All rights reserved.
%
% This file is part of the VLFeat library and is made available under
% the terms of the BSD license (see the COPYING file).

% ISSUE - needs to store internal state, another reason for having classes?

opts.epsilon = 1e-4;

backMode = numel(varargin) > 0 && ~ischar(varargin{1}) ;
if backMode
  dzdy = varargin{1} ;
  opts = vl_argparse(opts, varargin(2:end)) ;
else
  opts = vl_argparse(opts, varargin) ;
end

eps = opts.epsilon;
if isa(x, 'gpuArray')
  eps = gpuArray(opts.eps);
end

x_sz = size(x);
% Create an array of size #channels x #samples
x = permute(x, [3 1 2 4]);
x = reshape(x, x_sz(3), []);

% do the job
u = mean(x, 2);
v = var(x, 0, 2);

v_nf = sqrt(v + eps); % variance normalisation factor
x_mu = bsxfun(@minus, x, u);
x_n = bsxfun(@times, x_mu, 1./v_nf);

if ~backMode
  y = bsxfun(@times, x_n, g);
  y = bsxfun(@plus, y, b);
else
  
  dzdy = permute(dzdy, [3 1 2 4]);
  dzdy = reshape(dzdy, x_sz(3), []);
  
  m = size(x, 2);
  delta = eye(m, m, 'like', x);
  dudx = 1./m;
  dvdx = 2./(m - 1) .* x_mu * (delta - dudx);
  
  dzdx = zeros(size(x), 'like', x);
  delta = (eye(m, m, 'like', x) - dudx) ;
  
  for ch = 1:size(x,1)
    v_nf_d = -0.5 * (v(ch) + eps) .^ (-3/2);
    
    %x_mu_j = x_mu(ch, :);
    %dvdx_i = dvdx(ch, :);
    %dy_jdx_i = delta ./ v_nf(ch) + v_nf_d * x_mu_j' * dvdx_i;
    %dzdx(ch, :) = dzdy(ch,:) * dy_jdx_i;
    
    dzdx(ch, :) = dzdy(ch,:) * delta ./ v_nf(ch) + v_nf_d * (dzdy(ch,:) * x_mu(ch, :)') * dvdx(ch, :);    
  end

  y = dzdx;

  dzdg = sum(dzdy .* x_n, 2);
  dzdb = sum(dzdy, 2);
end

y = reshape(y, x_sz(3), x_sz(1), x_sz(2), x_sz(4));
y = permute(y, [2 3 1 4]);

end