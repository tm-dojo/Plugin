void drawRecordingOverlay() {
    int panelLeft = 10;
    int panelTop = 40;

    int panelWidth = g_dojo.recording ? 125 : 160;
    int panelHeight = 36;

    int topIncr = 18;

    // Rectangle
    nvg::BeginPath();
    nvg::RoundedRect(panelLeft, panelTop, panelWidth, panelHeight, 5);
    nvg::FillColor(vec4(0,0,0,0.5));
    nvg::Fill();
    nvg::ClosePath();

    // Define colors
    vec4 white = vec4(1, 1, 1, 1);
    vec4 orange = vec4(1, 0.5, 0, 1);
    vec4 gray = vec4(0.1, 0.1, 0.1, 1);
    vec4 red = vec4(0.95, 0.05, 0.05, 1);

    // Recording circle        
    int circleLeft = panelLeft + 18;
    int circleTop = panelTop + 18;
    nvg::BeginPath();        
    nvg::Circle(vec2(circleLeft, circleTop), 10);

    if (g_dojo.recording) {
        nvg::FillColor(red);
    } else if (Api::UploadingReplay) {
        nvg::FillColor(orange);
    } else{
        nvg::FillColor(gray);
    }

    nvg::Fill();
    nvg::StrokeColor(gray);
    nvg::StrokeWidth(3);
    nvg::Stroke();
    nvg::ClosePath();

    // Recording text
    int textLeft = panelLeft + 38;
    int textTop = panelTop + 23;

    if (g_dojo.recording) {
        nvg::FillColor(white);
        nvg::Text(textLeft, textTop, "Recording");
    } else if (Api::UploadingReplay) {
        nvg::FillColor(white);
        nvg::Text(textLeft, textTop, "Uploading");

        nvg::BeginPath();

        float timeOffset = (float(Time::Now) % 2000) / (Math::PI * 100);

        // First arc
        nvg::Arc(vec2(circleLeft, circleTop), 10.5, 1.2 + timeOffset, timeOffset, nvg::Winding::CCW);
        nvg::FillColor(orange);
        nvg::Fill();
        nvg::ClosePath();

        // Second arc on the opposite side
        nvg::BeginPath();
        nvg::Arc(vec2(circleLeft, circleTop), 10.5, 4.3 + timeOffset, 3.1 + timeOffset, nvg::Winding::CCW);
        nvg::FillColor(orange);
        nvg::Fill();
        nvg::ClosePath();
    } else{
        nvg::FillColor(white);
        nvg::Text(textLeft, textTop, "Not Recording");
    }
}