/*
    Copyright © 2020-2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module creator.windows.about;
import creator.widgets.dummy;
import creator.widgets.tooltip;
import creator.widgets.label;
import creator.widgets.markdown;
import creator.windows;
import creator.core;
import creator.config;
import creator;
import std.string;
import creator.utils.link;
import inochi2d;
import i18n;
import std.stdio;

class AboutWindow : Window {
private:
    version (InBranding) {
        enum ADA_SIZE = 332;
        enum ADA_SIZE_PARTIAL = ADA_SIZE/6;
        vec2 ada_float;
    }
    MarkdownConfig cfg;

protected:
    override
    void onBeginUpdate() {
        igSetNextWindowSize(ImVec2(640, 512), ImGuiCond.Appearing);
        igSetNextWindowSizeConstraints(ImVec2(640, 512), ImVec2(float.max, float.max));
        super.onBeginUpdate();
    }

    override
    void onUpdate() {

        // Draw Ada
        ImVec2 sPos;
        igGetCursorScreenPos(&sPos);

        version (InBranding) {
            ImVec2 avail = incAvailableSpace();
            igSetCursorScreenPos(ImVec2(
                sPos.x+(avail.x-(ADA_SIZE-ADA_SIZE_PARTIAL)), 
                sPos.y+(avail.y-(ADA_SIZE+28))+(sin(currentTime())*4)
            ));

            igImage(
                cast(void*)incGetAda().getTextureId(),
                ImVec2(ADA_SIZE, ADA_SIZE),
                ImVec2(0, 0),
                ImVec2(1, 1), 
                ImVec4(1, 1, 1, 0.4), ImVec4(0, 0, 0, 0)
            );
        }

        // Draw the actual about dialog
        igSetCursorScreenPos(sPos);
        if (igBeginChild("##LogoArea", ImVec2(0, 92))) {

            version (InBranding) {
                igImage(
                    cast(void*)incGetLogo().getTextureId(), 
                    ImVec2(64, 64), 
                    ImVec2(0, 0), 
                    ImVec2(1, 1), 
                    ImVec4(1, 1, 1, 1), 
                    ImVec4(0, 0, 0, 0)
                );
            }
            
            igSameLine(0, 8);
            igSeparatorEx(ImGuiSeparatorFlags.Vertical);
            igSameLine(0, 8);
            if (igBeginChild("##LogoTextArea", ImVec2(0, -24))) {

                incText("Inochi Creator");
                incText(INC_VERSION);
                igSeparator();
                igTextColored(ImVec4(0.5, 0.5, 0.5, 1), "I2D v. %s", (IN_VERSION~"\0").ptr);
                igTextColored(ImVec4(0.5, 0.5, 0.5, 1), "imgui v. %s", igGetVersion());
            }
            igEndChild();
            
            igSpacing();
            incText("Credits");
            igSeparator();
        }
        igEndChild();

        igPushStyleColor(ImGuiCol.Button, ImVec4(0.176, 0.447, 0.698, 1));
        igPushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.313, 0.521, 0.737, 1));
            if (igBeginChild("##CreditsArea", ImVec2(0, -28))) {
                incMarkdown(import("CONTRIBUTORS.md"), cfg);
            }
        igPopStyleColor();
        igPopStyleColor();
        igEndChild();

        if (igBeginChild("##ButtonArea", ImVec2(0, 0))) {
            ImVec2 space = incAvailableSpace();
            incDummy(ImVec2(space.x/2, space.y));
            igSameLine(0, 0);

            space = incAvailableSpace();
            float spacing = INC_RT_SHOW_DONATION_LINKS ? 
                (space.x/3)-8 : 
                (space.x/2)-8;

            if (igButton("GitHub", ImVec2(8+spacing, 0))) {
                incOpenLink("https://github.com/Inochi2D/inochi-creator");
            }

            igSameLine(0, 8);

            if (igButton("Twitter", ImVec2(spacing, 0))) {
                incOpenLink("https://twitter.com/Inochi2D");
            }

            static if (INC_RT_SHOW_DONATION_LINKS) {
                igSameLine(0, 8);

                if (igButton(__("Donate"), ImVec2(spacing, 0))) {
                    incOpenLink("https://www.patreon.com/clipsey");
                }
            }
        }
        igEndChild();
    }

public:
    this() {
        super(_("About"));
        this.onlyOne = true;

        cfg.headingFormats[0] = MarkdownHeadingFormat(2, true);
        cfg.headingFormats[1] = MarkdownHeadingFormat(1.5, false);
        cfg.headingFormats[2] = MarkdownHeadingFormat(1.2, false);
        cfg.linkCallback = (MarkdownLinkCallbackData data) {
            incOpenLink(data.link);
        };

        // Only load Ada in official builds
        version(InBranding) ada_float = vec2(0);
    }
}