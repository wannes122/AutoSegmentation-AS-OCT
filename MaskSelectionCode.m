% OCT Interactive Surface Annotation with Real-Time Fitting (Enhanced Zoom + Multi-point Refinement)
clc; clear; close all;

input_folder = 'C:\Users\G\Desktop\OCT Rabbit Eye Set 4 data cleaned';
output_folder = 'C:\Users\G\Desktop\OCT Rabbit Eye Set 4 masks';
file_list = dir(fullfile(input_folder, '*.PNG'));
file_names = {file_list.name};
file_names = file_names(~cellfun('isempty', regexp(file_names, '\d+')));
[~, idx] = sort(cellfun(@(x) str2double(regexp(x, '\d+', 'match', 'once')), file_names));
file_list = file_list(idx);

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

for file_num = 1:length(file_list)
    current_file = file_list(file_num).name;
    input_path = fullfile(input_folder, current_file);
    output_path = fullfile(output_folder, [erase(current_file, '.PNG') '_mask.PNG']);
    fprintf('Processing %d/%d: %s\n', file_num, length(file_list), current_file);

    try
        img = imread(input_path);
        if size(img, 3) == 3
            img = rgb2gray(img);
        end
        img = imadjust(img, [], [], 0.7);

        poly_order = 3;
        markerData = struct();

        [x_up_c_fit, y_up_c_fit, markerData.x_up_c, markerData.y_up_c] = refineSurfaceWithZoom(img, 'Cornea Upper Surface', 'r', poly_order, markerData);
        [x_down_c_fit, y_down_c_fit, markerData.x_down_c, markerData.y_down_c] = refineSurfaceWithZoom(img, 'Cornea Lower Surface', 'b', poly_order, markerData);
        [x_up_l_fit, y_up_l_fit, markerData.x_up_l, markerData.y_up_l] = refineSurfaceWithZoom(img, 'Lens Upper Surface', 'r', poly_order, markerData);
        [x_down_l_fit, y_down_l_fit, markerData.x_down_l, markerData.y_down_l] = refineSurfaceWithZoom(img, 'Lens Lower Surface', 'b', poly_order, markerData);

        figure('Name','Final Annotation Overview','Color','w');
        imshow(img); hold on;
        plot(markerData.x_up_c, markerData.y_up_c, 'ro', 'MarkerFaceColor','r');
        plot(markerData.x_down_c, markerData.y_down_c, 'bo', 'MarkerFaceColor','b');
        plot(markerData.x_up_l, markerData.y_up_l, 'ro', 'MarkerFaceColor','r');
        plot(markerData.x_down_l, markerData.y_down_l, 'bo', 'MarkerFaceColor','b');
        title('Final Overview Before Saving');
        plot(x_up_c_fit, y_up_c_fit, 'r-', 'LineWidth', 2);
        plot(x_down_c_fit, y_down_c_fit, 'b-', 'LineWidth', 2);
        plot(x_up_l_fit, y_up_l_fit, 'r-', 'LineWidth', 2);
        plot(x_down_l_fit, y_down_l_fit, 'b-', 'LineWidth', 2);
        uiwait(msgbox('Review complete annotation. Click OK to proceed to next image.'));

        [h, w] = size(img);
        label_img = zeros(h, w, 'uint8');

        mask_c = poly2mask([x_up_c_fit, fliplr(x_down_c_fit)], [y_up_c_fit, fliplr(y_down_c_fit)], h, w);
        mask_l = poly2mask([x_up_l_fit, fliplr(x_down_l_fit)], [y_up_l_fit, fliplr(y_down_l_fit)], h, w);
        label_img(mask_c) = 255;
        label_img(mask_l) = 150;

        fprintf('Pixels in Cornea Mask: %d, Lens Mask: %d\n', nnz(mask_c), nnz(mask_l));

        if nnz(label_img) > 0
            imwrite(label_img, output_path);
            fprintf('Saved: %s\n', output_path);
        else
            warning('Empty mask for %s — skipped.', current_file);
        end

    catch ME
        fprintf('Error processing %s: %s\n', current_file, ME.message);
    end
    close all;
end

fprintf('All files processed!\n');

function [x_fit_final, y_fit_final, x_final, y_final] = refineSurfaceWithZoom(img, surfaceName, color, poly_order, overlayData)
    if nargin < 5
        overlayData = struct();
    end

    fig_main = figure('Name', surfaceName, 'Color', 'w');
    imshow(img); hold on;
    title({'Select all points for surface', 'Left-click: Add | Right-click: Remove | Enter: Done'}, 'FontSize', 12);

    % Overlay previously annotated surfaces
    fields = fieldnames(overlayData);
    for f = 1:numel(fields)
        if startsWith(fields{f}, 'x')
            ykey = ['y' fields{f}(2:end)];
            if isfield(overlayData, ykey)
                col = 'r'; if contains(fields{f}, 'down'); col = 'b'; end
                plot(overlayData.(fields{f}), overlayData.(ykey), [col 'o'], 'MarkerFaceColor', col);
            end
        end
    end

    % Step 1: rough selection
    x_pts = [];
    y_pts = [];
    done = false;

    while ~done
        waitforbuttonpress;
        key = get(fig_main, 'CurrentCharacter');
        if strcmp(key, char(13))
            done = true;
        elseif strcmp(get(fig_main, 'SelectionType'), 'normal')
            pt = get(gca, 'CurrentPoint');
            x_pts(end+1) = pt(1,1);
            y_pts(end+1) = pt(1,2);
            plot(x_pts(end), y_pts(end), [color 'o'], 'MarkerSize', 10, 'MarkerFaceColor', color);
        elseif strcmp(get(fig_main, 'SelectionType'), 'alt') && ~isempty(x_pts)
            x_pts(end) = [];
            y_pts(end) = [];
            cla; imshow(img); hold on;

            % re-plot overlays
            for f = 1:numel(fields)
                if startsWith(fields{f}, 'x')
                    ykey = ['y' fields{f}(2:end)];
                    if isfield(overlayData, ykey)
                        col = 'r'; if contains(fields{f}, 'down'); col = 'b'; end
                        plot(overlayData.(fields{f}), overlayData.(ykey), [col 'o'], 'MarkerFaceColor', col);
                    end
                end
            end
            plot(x_pts, y_pts, [color 'o'], 'MarkerSize', 10, 'MarkerFaceColor', color);
        end
    end

    x_final = [];
    y_final = [];

    % Predeclare shared variables for nested function access
    ax = []; fig_zoom = []; img_crop = []; zoom_factor = 5;
    x_min = 0; y_min = 0;
    local_x = []; local_y = [];

    for i = 1:length(x_pts)
        x0 = round(x_pts(i)); y0 = round(y_pts(i));
        zoom_radius = 50;
        x_min = max(1, x0 - zoom_radius);
        x_max = min(size(img,2), x0 + zoom_radius);
        y_min = max(1, y0 - zoom_radius);
        y_max = min(size(img,1), y0 + zoom_radius);

        fig_zoom = figure('Name', sprintf('%s - Refine %d/%d', surfaceName, i, length(x_pts)), ...
                          'Position', [100 100 1800 1400]);

        img_crop = imresize(img(y_min:y_max, x_min:x_max), zoom_factor);
        ax = axes('Parent', fig_zoom);
       
        contrast_min = 0;
        contrast_max = 255;
        contrast_val = [min(img_crop(:)), max(img_crop(:))];
        
        imshow(img_crop, 'Parent', ax, 'DisplayRange', contrast_val); hold on;
        
        slider_y_base = -10;  % Pushes bars down
        slider_height = 30;
        
        uicontrol('Parent', fig_zoom, 'Style', 'text', 'String', 'Min Contrast', ...
                  'Position', [0, slider_y_base + 20, 100, slider_height]);
        
        slider_min = uicontrol('Parent', fig_zoom, 'Style', 'slider', ...
                  'Min', contrast_min, 'Max', contrast_max, 'Value', contrast_val(1), ...
                  'Position', [100, slider_y_base + 20, 200, slider_height]);
        
        uicontrol('Parent', fig_zoom, 'Style', 'text', 'String', 'Max Contrast', ...
                  'Position', [0, slider_y_base, 100, slider_height]);
        
        slider_max = uicontrol('Parent', fig_zoom, 'Style', 'slider', ...
                  'Min', contrast_min, 'Max', contrast_max, 'Value', contrast_val(2), ...
                  'Position', [100, slider_y_base, 200, slider_height]);

        
        % Callback to update contrast
        addlistener(slider_min, 'ContinuousValueChange', @(src, ~) updateContrast());
        addlistener(slider_max, 'ContinuousValueChange', @(src, ~) updateContrast());

        local_x = [];
        local_y = [];
        zoom_done = false;

        set(fig_zoom, 'WindowKeyPressFcn', @keyPressHandler);
        set(fig_zoom, 'WindowButtonDownFcn', @mouseClickHandler);
        uiwait(fig_zoom);

        x_final = [x_final, local_x];
        y_final = [y_final, local_y];

        close(fig_zoom);
    end

    % Final fitting & plot
    figure(fig_main); cla; imshow(img); hold on;
    for f = 1:numel(fields)
        if startsWith(fields{f}, 'x')
            ykey = ['y' fields{f}(2:end)];
            if isfield(overlayData, ykey)
                col = 'r'; if contains(fields{f}, 'down'); col = 'b'; end
                plot(overlayData.(fields{f}), overlayData.(ykey), [col 'o'], 'MarkerFaceColor', col);
            end
        end
    end
    plot(x_final, y_final, [color 'o'], 'MarkerSize', 10, 'MarkerFaceColor', color);
    [x_fit_final, y_fit_final] = polyfitCurve(x_final, y_final, poly_order);
    plot(x_fit_final, y_fit_final, [color '-'], 'LineWidth', 2);
    close(fig_main);

    % === Nested callback functions ===

    function keyPressHandler(~, event)
        if strcmp(event.Key, 'return')
            zoom_done = true;
            uiresume(fig_zoom);
        end
    end

    function mouseClickHandler(~, ~)
        pt = get(ax, 'CurrentPoint');
        x_click = round(pt(1,1) / zoom_factor) + x_min - 1;
        y_click = round(pt(1,2) / zoom_factor) + y_min - 1;
        selection = get(fig_zoom, 'SelectionType');

        if strcmp(selection, 'normal')
            local_x(end+1) = x_click;
            local_y(end+1) = y_click;
        elseif strcmp(selection, 'alt') && ~isempty(local_x)
            local_x(end) = [];
            local_y(end) = [];
        end

        cla(ax);
        vmin = slider_min.Value;
        vmax = slider_max.Value;
        imshow(img_crop, 'Parent', ax, 'DisplayRange', [vmin vmax]); hold(ax, 'on');

        for k = 1:length(local_x)
            plot(ax, (local_x(k) - x_min + 1) * zoom_factor, ...
                      (local_y(k) - y_min + 1) * zoom_factor, ...
                      'rx', 'MarkerSize', 12, 'LineWidth', 2);
        end
    end

    function updateContrast()
        vmin = slider_min.Value;
        vmax = slider_max.Value;
        if vmin >= vmax
            return;
        end
        imshow(img_crop, 'Parent', ax, 'DisplayRange', [vmin vmax]); hold(ax, 'on');
        for k = 1:length(local_x)
            plot(ax, (local_x(k) - x_min + 1) * zoom_factor, ...
                      (local_y(k) - y_min + 1) * zoom_factor, ...
                      'rx', 'MarkerSize', 12, 'LineWidth', 2);
        end
    end
end


function [x_fit, y_fit] = polyfitCurve(x, y, order)
    [x_sorted, idx] = sort(x);
    y_sorted = y(idx);
    p = polyfit(x_sorted, y_sorted, order);
    x_fit = linspace(min(x_sorted), max(x_sorted), 200);
    y_fit = polyval(p, x_fit);
end