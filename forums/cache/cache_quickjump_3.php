<?php

if (!defined('PUN')) exit;
define('PUN_QJ_LOADED', 1);

?>				<form id="qjump" method="get" action="viewforum.php">
					<div><label><?php echo $lang_common['Jump to'] ?>

					<br /><select name="id" onchange="window.location=('viewforum.php?id='+this.options[this.selectedIndex].value)">
						<optgroup label="Issue Specific">
							<option value="7"<?php echo ($forum_id == 7) ? ' selected="selected"' : '' ?>>Fall 2005</option>
							<option value="9"<?php echo ($forum_id == 9) ? ' selected="selected"' : '' ?>>Community Networking</option>
							<option value="10"<?php echo ($forum_id == 10) ? ' selected="selected"' : '' ?>>Community Organizing &amp; Development</option>
							<option value="11"<?php echo ($forum_id == 11) ? ' selected="selected"' : '' ?>>TA to NPOs</option>
							<option value="12"<?php echo ($forum_id == 12) ? ' selected="selected"' : '' ?>>Digital Media/Youth</option>
							<option value="13"<?php echo ($forum_id == 13) ? ' selected="selected"' : '' ?>>AmeriCorps/Corp. for National Service</option>
							<option value="15"<?php echo ($forum_id == 15) ? ' selected="selected"' : '' ?>>Big theme</option>
							<option value="18"<?php echo ($forum_id == 18) ? ' selected="selected"' : '' ?>>Special Theme:  Health (&amp; Safety)</option>
							<option value="19"<?php echo ($forum_id == 19) ? ' selected="selected"' : '' ?>>Future of Community Technology</option>
						</optgroup>
						<optgroup label="Management/Policy">
							<option value="17"<?php echo ($forum_id == 17) ? ' selected="selected"' : '' ?>>Proposals (and Suggestions)</option>
							<option value="16"<?php echo ($forum_id == 16) ? ' selected="selected"' : '' ?>>Finances</option>
							<option value="14"<?php echo ($forum_id == 14) ? ' selected="selected"' : '' ?>>Treating Hyperlinks</option>
						</optgroup>
						<optgroup label="Housekeeping">
							<option value="4"<?php echo ($forum_id == 4) ? ' selected="selected"' : '' ?>>Document Storage Area</option>
							<option value="6"<?php echo ($forum_id == 6) ? ' selected="selected"' : '' ?>>Forum Operations &amp; Conventions</option>
							<option value="20"<?php echo ($forum_id == 20) ? ' selected="selected"' : '' ?>>ComTechReview Email List Archives &gt;&gt;&gt;</option>
					</optgroup>
					</select>
					<input type="submit" value="<?php echo $lang_common['Go'] ?>" accesskey="g" />
					</label></div>
				</form>
