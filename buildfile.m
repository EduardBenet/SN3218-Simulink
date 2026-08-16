function plan = buildfile
import matlab.buildtool.tasks.*

plan = buildplan(localfunctions);

plan("clean") = CleanTask;
plan("check") = CodeIssuesTask('tbx', 'WarningThreshold',0, 'InfoThreshold',0);

plan("archive").Dependencies = ["clean", "check"];

plan.DefaultTasks = "archive";
end

function archiveTask(~)

v = ver('sn3218');

opts = matlab.addons.toolbox.ToolboxOptions("tbx", "c1b24a4c-c602-4a9b-8f70-95b411726782");
opts.AuthorCompany = "MathWorks";
opts.AuthorEmail = "ebenetcerda@gmail.com";
opts.AuthorName = "Eduard Benet Cerda";
opts.Description = "A simulink block for a SN3218 led driver";
opts.OutputFile = fullfile(currentProject().RootFolder, 'releases', 'sn3218.mltbx');
opts.Summary = "sn3218 block";
opts.ToolboxName = "sn3218";
opts.ToolboxVersion = v.Version;

matlab.addons.toolbox.packageToolbox(opts);

end