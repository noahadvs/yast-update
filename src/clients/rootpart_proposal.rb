# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# Module:	rootpart_proposal.ycp
#
# Author:	Arvin Schnell <arvin@suse.de>
#
# Purpose:	Let user choose root partition during update.
#
# $Id$
module Yast
  class RootpartProposalClient < Client
    def main
      Yast.import "UI"
      Yast.import "Pkg"
      textdomain "update"

      Yast.import "Mode"
      Yast.import "Linuxrc"
      Yast.import "Update"
      Yast.import "PackageCallbacks"
      Yast.import "RootPart"

      Yast.include self, "update/rootpart.rb"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}


      if @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        @language_changed = Ops.get_boolean(@param, "language_changed", false)

        PackageCallbacks.SetRebuildDBCallbacks

        # call some function that makes a proposal here:
        #
        # DummyMod::MakeProposal( force_reset );

        # Fill return map

        RootPart.selectedRootPartition = "" if @force_reset

        if RootPart.numberOfValidRootPartitions == 0 &&
            RootPart.selectedRootPartition == ""
          RootPart.targetOk = false

          @ret = {
            "warning" =>
              # Proposal for system to update
              _("No root partition found"),
            "warning_level" => :fatal,
            "raw_proposal"  => []
          }
        else
          if RootPart.selectedRootPartition == ""
            if RootPart.numberOfValidRootPartitions == 1 && !Linuxrc.manual
              RootPart.SetSelectedToValid
            else
              @result = Convert.to_symbol(
                WFM.CallFunction("inst_rootpart", [true, true, :update_popup])
              )
            end

            RootPart.targetOk = RootPart.mount_target
          elsif !RootPart.Mounted
            RootPart.targetOk = RootPart.mount_target
          end

          if RootPart.numberOfValidRootPartitions == 1
            @ret = { "raw_proposal" => [RootPart.GetInfoOfSelected(:name)] }
          else
            @ret = {
              "raw_proposal" =>
                # Proposal for system to update
                [
                  Builtins.sformat(
                    _("%1 on root partition %2"),
                    RootPart.GetInfoOfSelected(:name),
                    RootPart.selectedRootPartition
                  )
                ]
            }
          end

          if !RootPart.targetOk
            # inform user in the proposal about the failed mount
            @ret = Builtins.add(
              @ret,
              "warning",
              _("Failed to mount target system")
            )
            @ret = Builtins.add(@ret, "warning_level", :fatal)
            @ret = Builtins.add(@ret, "raw_proposal", [])
          end
        end
      elsif @func == "AskUser"
        @has_next = Ops.get_boolean(@param, "has_next", false)

        # call some function that displays a user dialog
        # or a sequence of dialogs here:
        #
        # sequence = DummyMod::AskUser( has_next );

        @tmp = RootPart.selectedRootPartition

        @result = RootPartitionDialog(:update_dialog_proposal)

        if @result == :next
          Update.Detach
          RootPart.UnmountPartitions(false) 

          #	    RootPart::targetOk = mount_target ();
        end

        # Fill return map

        @ret = {
          "workflow_sequence" => @result,
          "rootpart_changed"  => RootPart.selectedRootPartition != @tmp
        }
      elsif @func == "Description"
        # Fill return map.

        if Mode.normal
          @ret = {}
        else
          @ret = {
            # this is a heading
            "rich_text_title" => _("Selected for Update"),
            # this is a menu entry
            "menu_title"      => _(
              "&Selected for Update"
            ),
            "id"              => "rootpart_stuff"
          }
        end
      end

      deep_copy(@ret)
    end
  end
end

Yast::RootpartProposalClient.new.main